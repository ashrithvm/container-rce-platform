#!/bin/bash

# Lambda function update script
set -e

FUNCTION_TYPE=${1:-api}
AWS_REGION=${AWS_REGION:-us-east-1}
ENVIRONMENT=${ENVIRONMENT:-dev}

echo "🔄 Updating Lambda function: ${FUNCTION_TYPE}"

if [ "$FUNCTION_TYPE" == "api" ]; then
    cd aws-lambda/api
    npm install --production
    zip -r ../../api-lambda-update.zip . -x "*.git*" "node_modules/.cache/*"
    cd ../..
    
    aws lambda update-function-code \
        --function-name "container-rce-platform-api" \
        --zip-file fileb://api-lambda-update.zip \
        --region ${AWS_REGION}
    
    rm api-lambda-update.zip
    
elif [ "$FUNCTION_TYPE" == "executor" ]; then
    cd aws-lambda/executor
    npm install --production
    zip -r ../../executor-lambda-update.zip . -x "*.git*" "node_modules/.cache/*"
    cd ../..
    
    aws lambda update-function-code \
        --function-name "container-rce-platform-executor" \
        --zip-file fileb://executor-lambda-update.zip \
        --region ${AWS_REGION}
    
    rm executor-lambda-update.zip
    
else
    echo "Usage: $0 [api|executor]"
    exit 1
fi

echo "✅ Lambda function updated successfully"
