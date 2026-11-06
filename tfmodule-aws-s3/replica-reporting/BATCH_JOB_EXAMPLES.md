# S3 Batch Operations 대용량 객체 처리 예제

## 수많은 객체가 있는 경우의 처리 방법

### 1. S3 Inventory 사용 (권장)
**수백만 개 이상의 객체가 있는 경우**

```json
{
  "Manifest": {
    "Spec": {
      "Format": "S3InventoryReport_CSV_20161130"
    },
    "Location": {
      "ObjectArn": "arn:aws:s3:::report-bucket/inventory/2024/01/15/manifest.json",
      "ETag": "example-etag"
    }
  }
}
```

장점:
- 자동으로 매일/매주 생성
- 대용량 처리에 최적화
- 필터링 옵션 제공

### 2. CSV Manifest 직접 생성
**수천~수만 개 객체**

```bash
# 모든 객체 나열
aws s3 ls s3://source-bucket/ --recursive \
  | awk '{print "source-bucket," $4}' > manifest.csv

# 특정 패턴만 선택
aws s3 ls s3://source-bucket/ --recursive \
  | grep ".log$" \
  | awk '{print "source-bucket," $4}' > manifest-logs.csv
```

### 3. 조건부 Manifest 생성 예제

#### 최근 30일 이내 수정된 객체만
```bash
DATE_30_DAYS_AGO=$(date -d "30 days ago" +%Y-%m-%d)
aws s3api list-objects-v2 \
  --bucket source-bucket \
  --query "Contents[?LastModified>='$DATE_30_DAYS_AGO'].[join(',', [@, Key])]" \
  --output text | sed 's/^/source-bucket,/' > manifest-recent.csv
```

#### 특정 크기 범위의 객체만 (1MB ~ 100MB)
```bash
aws s3api list-objects-v2 \
  --bucket source-bucket \
  --query "Contents[?Size>=`1048576` && Size<=`104857600`].[join(',', [@, Key])]" \
  --output text | sed 's/^/source-bucket,/' > manifest-size-filtered.csv
```

#### 특정 태그를 가진 객체만
```bash
# 먼저 태그가 있는 객체 찾기
for key in $(aws s3api list-objects-v2 --bucket source-bucket --query 'Contents[].Key' --output text); do
  TAGS=$(aws s3api get-object-tagging --bucket source-bucket --key "$key" --query 'TagSet[?Key==`Replicate`]|[0].Value' --output text)
  if [ "$TAGS" == "true" ]; then
    echo "source-bucket,$key" >> manifest-tagged.csv
  fi
done
```

### 4. Batch Job 우선순위 및 동시성 설정

```json
{
  "Priority": 100,  // 높은 우선순위
  "Operation": {
    "S3ReplicateObject": {}  // 파라미터 없음 - 복제 규칙의 destination 사용
  },
  "Report": {
    "ReportScope": "FailedTasksOnly"  // 대용량 처리 시 실패만 기록
  }
}
```

### 5. 대용량 처리 최적화 팁

1. **Inventory 사용**: 수백만 개 이상
2. **Paginated List**: 10만 개 이하
3. **Priority 설정**: 중요도에 따라 1-2147483647
4. **Report Scope**:
   - 대용량: `FailedTasksOnly`
   - 소량: `AllTasks`
5. **Storage Class 최적화**: Batch Job 에서는 지정할 수 없으며, 복제 규칙의 `destination.storage_class` 로 설정
   - 자주 접근: `STANDARD`
   - 간헐적 접근: `STANDARD_IA`
   - 아카이브: `GLACIER_IR`, `DEEP_ARCHIVE`

### 6. 성능 고려사항

- **동시 Job 제한**: 계정당 1000개
- **처리 속도**: 초당 수천 개 객체
- **Manifest 크기**: 최대 1억 개 객체
- **비용**:
  - Job당 $0.25
  - 객체 1000개당 $0.0004

### 7. 모니터링

```bash
# Job 상태 확인
aws s3control describe-job \
  --account-id $ACCOUNT_ID \
  --job-id $JOB_ID

# Job 리스트
aws s3control list-jobs \
  --account-id $ACCOUNT_ID \
  --job-statuses Active

# CloudWatch 메트릭
- NumberOfTasksSucceeded
- NumberOfTasksFailed
- NumberOfTasksTotal
```