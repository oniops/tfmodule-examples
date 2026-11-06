#!/bin/bash

###############################################################################
# 복제 상태 확인 및 중복 방지 체크
###############################################################################

SOURCE_BUCKET=$(terraform output -raw source_bucket)
TARGET_BUCKET=$(terraform output -raw target_bucket)

echo "=== S3 객체 복제 상태 확인 ==="
echo "Source: $SOURCE_BUCKET"
echo "Target: $TARGET_BUCKET"
echo ""

# 1. Source 버킷의 모든 객체와 복제 상태 확인
echo "Source 버킷 객체 복제 상태:"
echo "--------------------------------"

aws s3api list-objects-v2 --bucket $SOURCE_BUCKET --query 'Contents[].Key' --output text | \
while read -r KEY; do
  if [ ! -z "$KEY" ]; then
    # 복제 상태 확인
    REPLICATION_STATUS=$(aws s3api head-object \
      --bucket $SOURCE_BUCKET \
      --key "$KEY" \
      --query ReplicationStatus \
      --output text 2>/dev/null)

    # 버전 ID 확인
    VERSION_ID=$(aws s3api head-object \
      --bucket $SOURCE_BUCKET \
      --key "$KEY" \
      --query VersionId \
      --output text 2>/dev/null)

    echo "객체: $KEY"
    echo "  - 버전 ID: ${VERSION_ID:-none}"
    echo "  - 복제 상태: ${REPLICATION_STATUS:-NOT_REPLICATED}"

    # Target 버킷에 존재 여부 확인
    if aws s3api head-object --bucket $TARGET_BUCKET --key "$KEY" >/dev/null 2>&1; then
      echo "  - Target 존재: ✓"
    else
      echo "  - Target 존재: ✗"
    fi
    echo ""
  fi
done

# 2. 복제 통계
echo ""
echo "=== 복제 통계 ==="

TOTAL=$(aws s3api list-objects-v2 --bucket $SOURCE_BUCKET --query 'length(Contents)' --output text)
COMPLETED=$(aws s3api list-objects-v2 --bucket $SOURCE_BUCKET --query 'Contents[?ReplicationStatus==`COMPLETED`] | length(@)' --output text)
PENDING=$(aws s3api list-objects-v2 --bucket $SOURCE_BUCKET --query 'Contents[?ReplicationStatus==`PENDING`] | length(@)' --output text)
TARGET_COUNT=$(aws s3api list-objects-v2 --bucket $TARGET_BUCKET --region ap-northeast-1 --query 'length(Contents)' --output text)

echo "Source 버킷 총 객체: ${TOTAL:-0}"
echo "복제 완료 (COMPLETED): ${COMPLETED:-0}"
echo "복제 대기 (PENDING): ${PENDING:-0}"
echo "Target 버킷 총 객체: ${TARGET_COUNT:-0}"

# 3. Replication Configuration 확인
echo ""
echo "=== Replication Rules 상태 ==="
aws s3api get-bucket-replication \
  --bucket $SOURCE_BUCKET \
  --query 'ReplicationConfiguration.Rules[].{ID:ID, Status:Status, Priority:Priority}' \
  --output table 2>/dev/null || echo "Replication Rules 없음"

# 4. 중복 가능성 체크
echo ""
echo "=== 중복 복제 위험 분석 ==="

if aws s3api get-bucket-replication --bucket $SOURCE_BUCKET >/dev/null 2>&1; then
  echo "✓ Replication Rules 활성화됨"

  # existing_object_replication 확인
  EXISTING_OBJ_REPL=$(aws s3api get-bucket-replication \
    --bucket $SOURCE_BUCKET \
    --query 'ReplicationConfiguration.Rules[?ExistingObjectReplication.Status==`Enabled`] | length(@)' \
    --output text)

  if [ "$EXISTING_OBJ_REPL" -gt 0 ]; then
    echo "⚠️  ExistingObjectReplication 활성화 - Batch Job과 중복 가능"
    echo "   권장: Batch Job 완료 후 ExistingObjectReplication 비활성화"
  else
    echo "✓ ExistingObjectReplication 비활성화 - 중복 위험 낮음"
  fi
else
  echo "✓ Replication Rules 없음 - Batch Operations 안전"
fi

echo ""
echo "=== 권장 사항 ==="
echo "1. Replication Rules는 신규 객체용으로 설정"
echo "2. 기존 객체는 Batch Operations로 1회만 복제"
echo "3. 복제 상태가 COMPLETED인 객체는 재복제되지 않음"
echo "4. existing_object_replication은 필요시에만 임시 활성화"