#!/bin/bash

###############################################################################
# 복제할 객체 목록을 `manifest.csv` 파일로 정의하여 batch-operations 처리
###############################################################################

# Terraform output에서 필요한 값 가져오기
SOURCE_BUCKET=$(terraform output -raw source_bucket)
TARGET_BUCKET=$(terraform output -raw target_bucket)
REPORT_BUCKET=$(terraform output -raw report_bucket)
ROLE_ARN=$(terraform output -raw replication_role_arn)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="ap-northeast-2"

echo "=== S3 Batch Operations Job 생성 ==="
echo "Source Bucket: $SOURCE_BUCKET"
echo "Target Bucket: $TARGET_BUCKET"
echo "Report Bucket: $REPORT_BUCKET"
echo "Role ARN: $ROLE_ARN"
echo ""

# 1. 매니페스트 파일 생성 (복제할 객체 목록)
echo "1. 매니페스트 파일 생성 중..."
cat > manifest.csv <<EOF
$SOURCE_BUCKET,test1.txt
$SOURCE_BUCKET,test2.txt
$SOURCE_BUCKET,folder/test3.txt
EOF

# 매니페스트를 Report 버킷에 업로드
aws s3 cp manifest.csv s3://$REPORT_BUCKET/manifests/manifest.csv
MANIFEST_ETAG=$(aws s3api head-object --bucket $REPORT_BUCKET --key manifests/manifest.csv --query ETag --output text | tr -d '"')

echo "Manifest ETag: $MANIFEST_ETAG"

# 2. Batch Job 설정 파일 생성
echo "2. Batch Job 설정 파일 생성 중..."
cat > batch-job.json <<EOF
{
  "AccountId": "$ACCOUNT_ID",
  "ConfirmationRequired": false,
  "Operation": {
    "S3ReplicateObject": {}
  },
  "Manifest": {
    "Spec": {
      "Format": "S3BatchOperations_CSV_20180820",
      "Fields": ["Bucket", "Key"]
    },
    "Location": {
      "ObjectArn": "arn:aws:s3:::$REPORT_BUCKET/manifests/manifest.csv",
      "ETag": "$MANIFEST_ETAG"
    }
  },
  "Priority": 10,
  "RoleArn": "$ROLE_ARN",
  "Report": {
    "Bucket": "arn:aws:s3:::$REPORT_BUCKET",
    "Prefix": "batch-reports",
    "Format": "Report_CSV_20180820",
    "Enabled": true,
    "ReportScope": "AllTasks"
  },
  "Description": "Replicate existing objects from source to target bucket"
}
EOF

# 3. Batch Job 생성
echo "3. Batch Job 생성 중..."
JOB_ID=$(aws s3control create-job \
  --region $REGION \
  --account-id $ACCOUNT_ID \
  --cli-input-json file://batch-job.json \
  --query JobId --output text)

echo ""
echo "=== Batch Job 생성 완료 ==="
echo "Job ID: $JOB_ID"
echo ""
echo "Job 상태 확인:"
echo "aws s3control describe-job --account-id $ACCOUNT_ID --job-id $JOB_ID --region $REGION"
echo ""
echo "리포트 확인 (작업 완료 후):"
echo "aws s3 ls s3://$REPORT_BUCKET/batch-reports/ --recursive"