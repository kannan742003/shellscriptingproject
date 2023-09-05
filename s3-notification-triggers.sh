#!/bin/bash

set -e

# Store the AWS account ID in a variable
aws_account_id=$(aws sts get-caller-identity --query 'Account' --output text)

# Print the AWS account ID from the variable
echo "AWS Account ID: $aws_account_id"

# Set AWS region and bucket name
aws_region="us-east-1"
bucket_name="kanna-ultimate-bucket"
lambda_func_name="lambda-function"
role_name="simplee-lambda-sns"
email_address="kannan742003@gmail.com"

# Create IAM Role for the project
role_response=$(aws iam create-role --role-name $role_name --assume-role-policy-document '{
  "Version": "2012-10-17",
  "Statement": [{
    "Action": "sts:AssumeRole",
    "Effect": "Allow",
    "Principal": {
      "Service": [
         "lambda.amazonaws.com",
         "s3.amazonaws.com",
         "sns.amazonaws.com"
      ]
    }
  }]
}')

# Extract the role ARN from the JSON response and store it in a variable
role_arn=$(echo "$role_response" | jq -r '.Role.Arn')

# Print the role ARN
echo "Role ARN: $role_arn"

# Attach Permissions to the Role
aws iam attach-role-policy --role-name $role_name --policy-arn arn:aws:iam::aws:policy/AWSLambda_FullAccess
aws iam attach-role-policy --role-name $role_name --policy-arn arn:aws:iam::aws:policy/AmazonSNSFullAccess

# Create the S3 bucket
aws s3api create-bucket --bucket "$bucket_name" --region "$aws_region"

# Upload a file to the bucket
aws s3 cp /C:/Users/Client/shellproject/shellscriptingproject/example_file.txt s3://"$bucket_name"/example_file.txt

# Create a Zip file to upload Lambda Function
#zip -r lambda-function.zip /C:/Users/Client/shellproject/shellscriptingproject/lambda-function

# Create a Lambda function
aws lambda create-function \
  --region "$aws_region" \
  --function-name $lambda_func_name \
  --runtime "python3.11" \
  --handler "lambda-function.lambda_handler" \
  --memory-size 128 \
  --timeout 30 \
  --role "$role_arn" \

# Add Permissions to S3 Bucket to invoke Lambda
aws lambda add-permission \
  --function-name "$lambda_func_name" \
  --statement-id "s3-lambda-sns" \
  --action "lambda:InvokeFunction" \
  --principal s3.amazonaws.com \
  --source-arn "arn:aws:s3:::$bucket_name"

# Create an S3 event trigger for the Lambda function
LambdaFunctionArn="arn:aws:lambda:$aws_region:$aws_account_id:function:$lambda_func_name"
aws s3api put-bucket-notification-configuration \
  --region "$aws_region" \
  --bucket "$bucket_name" \
  --notification-configuration '{
    "LambdaFunctionConfigurations": [{
        "LambdaFunctionArn": "'"$LambdaFunctionArn"'",
        "Events": ["s3:ObjectCreated:*"]
    }]
}'

# Create an SNS topic and save the topic ARN to a variable
topic_arn=$(aws sns create-topic --name simplee-lambda-sns --output json | jq -r '.TopicArn')

# Print the TopicArn
echo "SNS Topic ARN: $topic_arn"

# Add SNS publish permission to the Lambda Function
aws lambda add-permission \
  --function-name "$lambda_func_name" \
  --statement-id "sns-lambda-permission" \
  --action "lambda:InvokeFunction" \
  --principal sns.amazonaws.com \
  --source-arn "$topic_arn"

# Publish SNS
aws sns publish \
  --topic-arn "$topic_arn" \
  --subject "A new object created in S3 bucket" \
  --message "Hello from Abhishek.Veeramalla YouTube channel, Learn DevOps Zero to Hero for Free"

echo "Script executed successfully"




