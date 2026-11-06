#!/bin/bash

###############################################################################
# 대용량인 경우 `inventory-config.json` 규칙을 통해 batch-operations 방식으로 처리
###############################################################################

# Terraform output에서 필요한 값 가져오기
SOURCE_BUCKET=$(terraform output -raw source_bucket)
TARGET_BUCKET=$(terraform output -raw target_bucket)
REPORT_BUCKET=$(terraform output -raw report_bucket)
ROLE_ARN=$(terraform output -raw replication_role_arn)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="ap-northeast-2"

echo "=== S3 Inventory를 사용한 Batch Operations Job 생성 ==="
echo ""

# 1. S3 Inventory 설정 (소스 버킷의 모든 객체 목록 자동 생성)
echo "1. S3 Inventory 설정 중..."
cat > inventory-config.json <<EOF
{
  "Destination": {
    "S3BucketDestination": {
      "AccountId": "$ACCOUNT_ID",
      "Bucket": "arn:aws:s3:::$REPORT_BUCKET",
      "Prefix": "inventory",
      "Format": "CSV",
      "Encryption": {
        "SSES3": {}
      }
    }
  },
  "IsEnabled": true,
  "Id": "BatchReplicationInventory",
  "IncludedObjectVersions": "Current",
  "OptionalFields": [
    "Size",
    "LastModifiedDate",
    "StorageClass",
    "ETag",
    "IsMultipartUploaded",
    "ReplicationStatus"
  ],
  "Schedule": {
    "Frequency": "Daily"
  }
}
EOF

# Inventory 설정 적용
aws s3api put-bucket-inventory-configuration \
  --bucket $SOURCE_BUCKET \
  --id BatchReplicationInventory \
  --inventory-configuration file://inventory-config.json

echo "Inventory 설정 완료. 첫 번째 리포트는 24-48시간 내에 생성됩니다."
echo ""

# 2. 즉시 사용 가능한 방법: S3 Select를 사용한 manifest 생성
echo "2. 대안: S3 리스트를 사용한 즉시 manifest 생성..."

# S3 버킷의 모든 객체 나열하여 manifest.csv 생성
aws s3api list-objects-v2 \
  --bucket $SOURCE_BUCKET \
  --query 'Contents[?StorageClass==`STANDARD`].[join(`,`, [@, Key])]' \
  --output text | sed "s/^/$SOURCE_BUCKET,/" > manifest-all.csv

# manifest를 Report 버킷에 업로드
aws s3 cp manifest-all.csv s3://$REPORT_BUCKET/manifests/manifest-all.csv
MANIFEST_ETAG=$(aws s3api head-object --bucket $REPORT_BUCKET --key manifests/manifest-all.csv --query ETag --output text | tr -d '"')

echo "Manifest 생성 완료. 총 $(wc -l < manifest-all.csv) 개 객체"
echo ""

# 3. Batch Job 생성 (모든 객체 복제)
echo "3. Batch Job 설정 파일 생성 중..."
cat > batch-job-all.json <<EOF
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
      "ObjectArn": "arn:aws:s3:::$REPORT_BUCKET/manifests/manifest-all.csv",
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
  "Description": "Replicate all existing objects from source to target bucket"
}
EOF

# 4. Batch Job 생성
echo "4. Batch Job 생성 중..."
JOB_ID=$(aws s3control create-job \
  --region $REGION \
  --account-id $ACCOUNT_ID \
  --cli-input-json file://batch-job-all.json \
  --query JobId --output text)

echo ""
echo "=== Batch Job 생성 완료 ==="
echo "Job ID: $JOB_ID"
echo "복제할 객체 수: $(wc -l < manifest-all.csv)"
echo ""
echo "Job 상태 확인:"
echo "aws s3control describe-job --account-id $ACCOUNT_ID --job-id $JOB_ID --region $REGION"