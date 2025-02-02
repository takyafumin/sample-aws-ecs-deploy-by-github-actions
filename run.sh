#!/bin/bash

# コマンドライン引数をチェック
case "$1" in
    "build")
        # Dockerイメージをビルド
        docker build -t php-app -f .docker/php/Dockerfile .
        echo "Dockerイメージのビルドが完了しました。"
        ;;
    "deploy:network")
        # network.ymlをデプロイ
        aws cloudformation deploy \
            --template-file ${AWS_CFN_TEMPLATE_PATH}/network.yml \
            --stack-name ${AWS_CFN_STACK_NAME} \
            --capabilities CAPABILITY_NAMED_IAM
        echo "ネットワークリソースのデプロイが完了しました。"
        ;;
    *)
        echo "使用方法: ./run.sh [command]"
        echo "利用可能なコマンド:"
        echo "  build          - Dockerイメージをビルドします"
        ;;
esac
