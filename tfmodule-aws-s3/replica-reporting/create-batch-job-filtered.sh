#!/bin/bash

###############################################################################
# 복제할 객체 목록을 `manifest-filtered.csv` 파일로 정의후 batch-operations 방식으로 처리
###############################################################################

# Terraform output에서 필요한 값 가져오기
SOURCE_BUCKET=$(terraform output -raw source_bucket)
TARGET_BUCKET=$(terraform output -raw target_bucket)
REPORT_BUCKET=$(terraform output -raw report_bucket)
ROLE_ARN=$(terraform output -raw replication_role_arn)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="ap-northeast-2"

echo "=== 필터링된 S3 Batch Operations Job 생성 ==="
echo ""

# 1. 특정 조건으로 필터링된 manifest 생성
echo "필터 옵션을 선택하세요:"
echo "1) 특정 prefix를 가진 객체만"
echo "2) 특정 날짜 이후 수정된 객체만"
echo "3) 특정 크기 이상의 객체만"
echo "4) 특정 Storage Class의 객체만"
read -p "선택 (1-4): " OPTION

case $OPTION in
  1)
    read -p "Prefix 입력 (예: logs/, data/2024/): " PREFIX
    echo "Prefix '$PREFIX'를 가진 객체 목록 생성 중..."
    aws s3api list-objects-v2 \
      --bucket $SOURCE_BUCKET \
      --prefix "$PREFIX" \
      --query 'Contents[].[join(`,`, [@, Key])]' \
      --output text | sed "s/^/$SOURCE_BUCKET,/" > manifest-filtered.csv
    ;;

  2)
    read -p "날짜 입력 (YYYY-MM-DD): " DATE
    echo "$DATE 이후 수정된 객체 목록 생성 중..."
    aws s3api list-objects-v2 \
      --bucket $SOURCE_BUCKET \
      --query "Contents[?LastModified>=\`$DATE\`].[join(\`,\`, [@, Key])]" \
      --output text | sed "s/^/$SOURCE_BUCKET,/" > manifest-filtered.csv
    ;;

  3)
    read -p "최소 크기 입력 (bytes, 예: 1048576 = 1MB): " MIN_SIZE
    echo "$MIN_SIZE bytes 이상의 객체 목록 생성 중..."
    aws s3api list-objects-v2 \
      --bucket $SOURCE_BUCKET \
      --query "Contents[?Size>=\`$MIN_SIZE\`].[join(\`,\`, [@, Key])]" \
      --output text | sed "s/^/$SOURCE_BUCKET,/" > manifest-filtered.csv
    ;;

  4)
    echo "Storage Class 옵션: STANDARD, STANDARD_IA, GLACIER, DEEP_ARCHIVE"
    read -p "Storage Class 입력: " STORAGE_CLASS
    echo "Storage Class '$STORAGE_CLASS'인 객체 목록 생성 중..."
    aws s3api list-objects-v2 \
      --bucket $SOURCE_BUCKET \
      --query "Contents[?StorageClass==\`$STORAGE_CLASS\`].[join(\`,\`, [@, Key])]" \
      --output text | sed "s/^/$SOURCE_BUCKET,/" > manifest-filtered.csv
    ;;
esac

# manifest가 비어있는지 확인
if [ ! -s manifest-filtered.csv ]; then
  echo "조건에 맞는 객체가 없습니다."
  exit 1
fi

echo "필터링된 객체 수: $(wc -l < manifest-filtered.csv)"

# 2. manifest를 Report 버킷에 업로드
aws s3 cp manifest-filtered.csv s3://$REPORT_BUCKET/manifests/manifest-filtered.csv
MANIFEST_ETAG=$(aws s3api head-object --bucket $REPORT_BUCKET --key manifests/manifest-filtered.csv --query ETag --output text | tr -d '"')

# 3. Batch Job 설정 파일 생성
# S3ReplicateObject 는 파라미터가 없으며, 대상 버킷/스토리지 클래스/KMS 는 소스 버킷의 복제 규칙을 따릅니다.
cat > batch-job-filtered.json <<EOF
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
      "ObjectArn": "arn:aws:s3:::$REPORT_BUCKET/manifests/manifest-filtered.csv",
      "ETag": "$MANIFEST_ETAG"
    }
  },
  "Priority": 10,
  "RoleArn": "$ROLE_ARN",
  "Report": {
    "Bucket": "arn:aws:s3:::$REPORT_BUCKET",
    "Prefix": "batch-reports-filtered",
    "Format": "Report_CSV_20180820",
    "Enabled": true,
    "ReportScope": "FailedTasksOnly"
  },
  "Description": "Replicate filtered objects using the source bucket replication rule"
}
EOF

# 4. Batch Job 생성
echo ""
echo "Batch Job 생성 중..."
JOB_ID=$(aws s3control create-job \
  --region $REGION \
  --account-id $ACCOUNT_ID \
  --cli-input-json file://batch-job-filtered.json \
  --query JobId --output text)

echo ""
echo "=== Batch Job 생성 완료 ==="
echo "Job ID: $JOB_ID"
echo "복제할 객체 수: $(wc -l < manifest-filtered.csv)"
echo "대상: 소스 버킷 복제 규칙의 destination ($TARGET_BUCKET)"
echo ""
echo "Job 진행 상태 확인:"
echo "aws s3control describe-job --account-id $ACCOUNT_ID --job-id $JOB_ID --region $REGION"