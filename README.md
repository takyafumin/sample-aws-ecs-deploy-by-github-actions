# sample-aws-ecs-deploy-by-github-actions
Github Actions を使って ECS をデプロイするサンプル

## 概要
laravelプロジェクトを、Github Actionsを利用してAWS ECS on Fargateへデプロイしたい。

### 前提条件
- DBはsqlite
- AWSアカウントは取得済み
- web上でAWSリソースを操作するIAMユーザーは作成済み
- AWSリソースの管理はCloudformationとする
- CloudformationはAWS CLIで操作する
- AWS CLIの設定は済み
- RDSは不要

### 考慮対象外
- DBデータの永続化
- 複数コンテナ間のデータ整合性
- バックアップ戦略

## AWSアーキテクチャ

```mermaid
graph TB
    subgraph VPC
        subgraph "Public Subnet"
            ECS[ECS Service]
            SG[Security Group]
            VPCEndpoints[VPC Endpoints]
            ECS -->|uses| SG
            ECS -->|uses| VPCEndpoints
        end
    end

    subgraph "Container Registry"
        ECR[ECR Repository]
    end

    subgraph "Compute"
        ECS_CLUSTER[ECS Cluster]
        TASK_DEF[Task Definition]
        TASK_ROLE[Task Role]
        EXECUTION_ROLE[Task Execution Role]
    end

    subgraph "Monitoring"
        CW_LOGS[CloudWatch Logs]
    end

    ECR -->|provides image| TASK_DEF
    TASK_DEF -->|runs on| ECS_CLUSTER
    ECS -->|uses| TASK_DEF
    TASK_DEF -->|assumes| TASK_ROLE
    TASK_DEF -->|assumes| EXECUTION_ROLE
    ECS -->|logs to| CW_LOGS
```

## リソース構成

### ネットワークスタック (`network.yml`)
- VPC
  - CIDR: 10.0.0.0/16
  - Public Subnet: 10.0.1.0/24
  - Internet Gateway
  - Route Table
- Security Group
  - Inbound: 8000, 443 (VPCエンドポイント用)
  - Outbound: All
- VPCエンドポイント
  - ECR API
  - ECR DKR
  - CloudWatch Logs
  - S3
- ECR Repository
  - Name: laravel-app
  - Image Scanning: Enabled

### ECSスタック (`ecs.yml`)
- ECS Cluster
  - Name: laravel-ecs-cluster
- Task Definition
  - CPU: 256
  - Memory: 512
  - Network Mode: awsvpc
  - Platform: FARGATE
  - Container Port: 8000
  - Health Check: Enabled
- ECS Service
  - Name: laravel-service
  - Desired Count: 1
  - Launch Type: FARGATE
  - Network: Public Subnet
  - Health Check Grace Period: 120s
- IAM Roles
  - Task Execution Role
  - Task Role
- CloudWatch Logs
  - Log Group: /ecs/laravel-app
  - Retention: 7 days

## デプロイ手順

```bash
# 1. ネットワークリソースをデプロイ
./run.sh deploy:network

# 2. Dockerイメージをビルド
./run.sh build

# 3. ECRにイメージをプッシュ
./run.sh push:ecr

# 4. ECSリソースをデプロイ
./run.sh deploy:ecs

# 5. アプリケーションのエンドポイントを確認
./run.sh show:endpoint
```

## Tips

### ECSコンテナへのSSM接続

```bash
./run.sh ssm
```
