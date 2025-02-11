#!/bin/bash

AWS_CFN_STACK_NAME="laravel-network-stack"
AWS_ECS_STACK_NAME="laravel-ecs-stack"
AWS_CFN_TEMPLATE_PATH=".aws"
AWS_REGION="ap-northeast-1"
AWS_ECS_TASK_DEFINITION_PATH="${AWS_CFN_TEMPLATE_PATH}/ecs-task-definition.json"

# スタックの状態を確認する関数
check_stack_status() {
    local stack_name=$1
    aws cloudformation describe-stacks \
        --stack-name ${stack_name} \
        --query 'Stacks[0].StackStatus' \
        --output text 2>/dev/null || echo "DOES_NOT_EXIST"
}

# スタックの作成/更新完了を待機する関数
wait_for_stack() {
    local stack_name=$1
    echo "スタックの作成/更新完了を待機中..."
    aws cloudformation wait stack-create-complete --stack-name ${stack_name} 2>/dev/null || \
    aws cloudformation wait stack-update-complete --stack-name ${stack_name}
}

# コマンドライン引数をチェック
case "$1" in
    "build")
        # buildxを使用してビルド
        docker buildx build \
            --platform linux/amd64 \
            --load \
            -t php-app \
            -f .docker/php/Dockerfile .
        echo "Dockerイメージのビルドが完了しました。"
        ;;
    "deploy:network")
        # network.ymlをデプロイ
        aws cloudformation deploy \
            --template-file ${AWS_CFN_TEMPLATE_PATH}/network.yml \
            --stack-name ${AWS_CFN_STACK_NAME} \
            --capabilities CAPABILITY_NAMED_IAM
        RETURN_CODE=$?
        if [ $RETURN_CODE -ne 0 ]; then
            echo "ネットワークリソースのデプロイに失敗しました。"
            exit 1
        fi
        echo "ネットワークリソースのデプロイが完了しました。"
        ;;
    "deploy:ecs")
        CURRENT_TIME=$(date +%s)

        # スタックの状態を確認
        echo "Checking stack status..."
        STACK_STATUS=$(check_stack_status ${AWS_ECS_STACK_NAME})
        echo "Stack status: ${STACK_STATUS}"

        # ROLLBACK_COMPLETEの場合、スタックを削除
        if [ "${STACK_STATUS}" = "ROLLBACK_COMPLETE" ]; then
            echo "Deleting ROLLBACK_COMPLETE stack..."
            aws cloudformation delete-stack --stack-name ${AWS_ECS_STACK_NAME}
            echo "Waiting for stack deletion to complete..."
            aws cloudformation wait stack-delete-complete --stack-name ${AWS_ECS_STACK_NAME}
        fi

        # ECSスタックをデプロイ
        echo "Deploying ECS stack..."
        aws cloudformation deploy \
            --template-file ${AWS_CFN_TEMPLATE_PATH}/ecs.yml \
            --stack-name ${AWS_ECS_STACK_NAME} \
            --capabilities CAPABILITY_NAMED_IAM \
            --parameter-overrides \
            DeployTime="${CURRENT_TIME}"
        RETURN_CODE=$?
        if [ $RETURN_CODE -ne 0 ]; then
            echo "ECSリソースのデプロイに失敗しました。"
            exit 1
        fi

        # スタックの更新完了を待機
        echo "Waiting for stack update to complete..."
        wait_for_stack ${AWS_ECS_STACK_NAME}

        echo "ECSリソースのデプロイが完了しました。"
        ;;
    "push:ecr")
        # ECRリポジトリ名を取得（スタックのOutputから）
        REPOSITORY_NAME=$(aws cloudformation describe-stacks \
            --stack-name ${AWS_CFN_STACK_NAME} \
            --query 'Stacks[0].Outputs[?OutputKey==`ECRRepositoryName`].OutputValue' \
            --output text)

        # ECRリポジトリURIを取得（スタックのOutputから）
        REPOSITORY_URI=$(aws cloudformation describe-stacks \
            --stack-name ${AWS_CFN_STACK_NAME} \
            --query 'Stacks[0].Outputs[?OutputKey==`ECRRepositoryUri`].OutputValue' \
            --output text)

        # ECRにログイン
        aws ecr get-login-password --region ${AWS_REGION} | \
            docker login --username AWS --password-stdin ${REPOSITORY_URI}

        # イメージにタグを付けてプッシュ
        docker tag php-app:latest ${REPOSITORY_URI}:latest
        docker push ${REPOSITORY_URI}:latest
        echo "ECRへのイメージプッシュが完了しました。"
        ;;
    "delete:stacks")
        echo "ECSスタックを削除中..."
        aws cloudformation delete-stack --stack-name ${AWS_ECS_STACK_NAME}
        echo "ECSスタックの削除完了を待機中..."
        aws cloudformation wait stack-delete-complete --stack-name ${AWS_ECS_STACK_NAME}

        # ECRリポジトリ名を取得
        REPOSITORY_NAME=$(aws cloudformation describe-stacks \
            --stack-name ${AWS_CFN_STACK_NAME} \
            --query 'Stacks[0].Outputs[?OutputKey==`ECRRepositoryName`].OutputValue' \
            --output text)

        echo "ECRリポジトリのイメージを削除中..."
        aws ecr list-images \
            --repository-name ${REPOSITORY_NAME} \
            --query 'imageIds[*]' \
            --output json | \
        aws ecr batch-delete-image \
            --repository-name ${REPOSITORY_NAME} \
            --image-ids file:///dev/stdin || true

        echo "ネットワークスタックを削除中..."
        aws cloudformation delete-stack --stack-name ${AWS_CFN_STACK_NAME}
        echo "ネットワークスタックの削除完了を待機中..."
        aws cloudformation wait stack-delete-complete --stack-name ${AWS_CFN_STACK_NAME}

        echo "全てのスタックの削除が完了しました。"
        ;;
    "show:endpoint")
        # ECSタスクのパブリックIPを取得
        TASK_ARN=$(aws ecs list-tasks \
            --cluster laravel-ecs-cluster \
            --service-name laravel-service \
            --query 'taskArns[0]' \
            --output text)

        if [ -z "$TASK_ARN" ] || [ "$TASK_ARN" = "None" ]; then
            echo "実行中のECSタスクが見つかりません。"
            exit 1
        fi

        ENI_ID=$(aws ecs describe-tasks \
            --cluster laravel-ecs-cluster \
            --tasks $TASK_ARN \
            --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
            --output text)

        PUBLIC_IP=$(aws ec2 describe-network-interfaces \
            --network-interface-ids $ENI_ID \
            --query 'NetworkInterfaces[0].Association.PublicIp' \
            --output text)

        echo "アプリケーションエンドポイント: http://${PUBLIC_IP}:8000"
        ;;
    "ssm")
        # Get the first task ARN
        TASK_ID=$(aws ecs list-tasks --cluster laravel-ecs-cluster --query 'taskArns[0]' --output text | awk -F'/' '{print $3}')
        if [ -z "$TASK_ID" ]; then
            echo "No running tasks found"
            exit 1
        fi

        # Connect to the container
        aws ecs execute-command \
            --cluster laravel-ecs-cluster \
            --task $TASK_ID \
            --container laravel-app \
            --command "/bin/bash" \
            --interactive
        ;;
    "help"|*)
        echo "使用方法: ./run.sh [command]"
        echo "利用可能なコマンド:"
        echo "  build          - Dockerイメージをビルドします"
        echo "  deploy:network - ネットワークリソースをデプロイします"
        echo "  deploy:ecs     - ECSリソースをデプロイします"
        echo "  push:ecr       - ECRにイメージをプッシュします"
        echo "  delete:stacks  - 全てのスタックを削除します"
        echo "  show:endpoint  - アプリケーションのエンドポイントを表示します"
        echo "  ssm            - Connect to ECS container using SSM"
        ;;
esac
