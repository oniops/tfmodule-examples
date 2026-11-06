# S3 복제 + Batch Operations 리포트 예제

이 예제는 tfmodule-aws-s3 로 **Cross-Region 복제 규칙**을 구성하고, 규칙 생성 이전부터 있던 객체를 **S3 Batch Replication**(Batch Operations)으로 복제하는 방법을 보여 줍니다.
Batch Job 의 실행 결과 리포트는 별도의 **리포트 버킷**에 저장합니다.

- 신규 객체: 복제 규칙(`replication_rules`)에 따라 자동으로 비동기 복제
- 기존 객체: Batch Operations Job 으로 한 번 복제 (`existing_object_replication = false` 로 두고 별도 처리)

## 구성

```
                 ap-northeast-2                              ap-northeast-1
┌───────────────────────────────────────┐        ┌───────────────────────────────────┐
│ source  (versioning, replication)     │ ─────▶ │ target (versioning)               │
│   └─ IAM Role: ...S3CrrRole           │  복제   │                                   │
│ report  (Batch manifest / report)     │        │                                   │
└───────────────────────────────────────┘        └───────────────────────────────────┘
```

| 모듈 | 버킷 이름 (context: project=`demo`, region=`ap-northeast-2`, env=`PoC`) | 리전 | 설정 |
|------|------|------|------|
| `module.source` | `demo-an2p-exr401-report-replica-source-s3` | ap-northeast-2 | 버전 관리, 복제 규칙, 복제 IAM Role 자동 생성, SSE-S3(AES256) |
| `module.target` | `demo-an2p-exr401-report-replica-target-s3` | ap-northeast-1 (`aws.replica`) | 버전 관리 (복제 대상 필수), SSE-S3(AES256) |
| `module.report` | `demo-an2p-exr401-report-replica-report-s3` | ap-northeast-2 | Batch Job manifest·리포트 저장용 (버전 관리 없음) |

세 버킷 모두 `object_ownership = "ObjectWriter"`, 퍼블릭 액세스 차단, `force_destroy = true`(PoC 용) 로 생성됩니다.
버킷 접두어(`demo-an2p`)는 [tfmodule-context](https://github.com/oniops/tfmodule-context) `v1.3.6` 이 context 값으로 만듭니다.

### 복제 규칙

```hcl
replication_rules = {
  "report-replica-rule" = {
    priority                    = 0
    delete_marker_replication   = false   # 삭제 마커는 복제하지 않음
    existing_object_replication = false   # 기존 객체는 Batch Operations 로 별도 처리

    destination = {
      bucket = module.target.bucket_arn
      # replication_time = true   # RTC(15분 SLA) - 추가 요금, metrics 필요
      # metrics          = true   # 복제 메트릭 - 추가 요금
    }
  }
}
```

| 항목 | 값 | 설명 |
|------|----|------|
| 필터 | 없음 | 버킷의 **모든 객체**를 복제 |
| 스토리지 클래스 | 미지정 | 원본과 동일 |
| RTC / 메트릭 | 끔 | 비용 절감을 위해 사용하지 않음. 복제는 RTC 없이도 비동기로 수행되며, "15분 내 완료" SLA 만 없음 |
| `replication_report_bucket_arn` | `module.report.bucket_arn` | 복제 IAM Role 에 리포트 버킷 쓰기 권한 추가 |

### 자동 생성되는 IAM Role

`replication_role_arn` 을 지정하지 않았으므로 모듈이 Role 과 Policy 를 만들어 연결합니다 (`aws_iam_role_policy_attachment`).

- Role: `demoExr401ReportReplicaSourceS3CrrRole`
- Policy: `demoExr401ReportReplicaSourceS3CrrPolicy`
- Trust: `s3.amazonaws.com`, `batchoperations.s3.amazonaws.com` (복제와 Batch Job 이 같은 Role 을 사용)

| Sid | 권한 | 대상 |
|-----|------|------|
| `AllowPutReportBucket` | `s3:PutObject` | 리포트 버킷 (Batch Job 결과 리포트 저장) |
| `AllowGetManifestFromReportBucket` | `s3:GetObject`, `s3:GetObjectVersion` | 리포트 버킷 객체 (Batch Job manifest 읽기) |
| `AllowPrimaryToInitiateReplication` | `s3:InitiateReplication` | 소스 버킷 |
| `AllowPrimaryToGetReplication` | `s3:ListBucket`, `s3:GetReplicationConfiguration`, `s3:PutInventoryConfiguration`, `s3:GetObjectVersion*` 등 | 소스 버킷 |
| `AllowPrimaryToReplicate` | `s3:ReplicateObject`, `s3:ReplicateDelete`, `s3:ReplicateTags` 등 | 대상 버킷 |

### Outputs

| 이름 | 값 |
|------|----|
| `source_bucket` | 소스 버킷 이름 |
| `target_bucket` | 대상 버킷 이름 |
| `report_bucket` | 리포트 버킷 이름 |
| `replication_role_arn` | 복제/Batch Job 에 사용하는 IAM Role ARN |

## 실행 방법

### 1. 인프라 배포

```bash
export AWS_PROFILE=<profile>
terraform init
terraform plan    # Plan: 21 to add
terraform apply
```

### 2. 테스트 파일 업로드

복제 규칙이 있으므로 이 단계에서 업로드한 객체는 **자동으로 복제**됩니다.
Batch Replication 을 테스트하려면 복제 규칙을 만들기 전의 객체가 필요하므로, 실제 마이그레이션 상황에서는 기존 버킷에 이미 있는 객체가 대상이 됩니다.

```bash
echo "Test content 1" > test1.txt
echo "Test content 2" > test2.txt
mkdir -p folder && echo "Test content 3" > folder/test3.txt

SOURCE_BUCKET=$(terraform output -raw source_bucket)
aws s3 cp test1.txt s3://$SOURCE_BUCKET/
aws s3 cp test2.txt s3://$SOURCE_BUCKET/
aws s3 cp folder/test3.txt s3://$SOURCE_BUCKET/folder/
```

### 3. Batch Operations Job 생성

모든 스크립트는 `terraform output` 과 `aws sts get-caller-identity` 로 버킷·Role·계정 정보를 읽고, `ap-northeast-2`(소스 리전)에 Job 을 만듭니다.
manifest 는 리포트 버킷의 `manifests/` 에, 실행 결과는 `batch-reports/` 에 저장됩니다.

| 스크립트 | 용도 |
|----------|------|
| `create-batch-job.sh` | 고정 manifest(`test1.txt`, `test2.txt`, `folder/test3.txt`)로 Job 생성 |
| `create-batch-job-filtered.sh` | 대화형으로 필터 선택 후 manifest 생성: ① prefix ② 수정 날짜 ③ 최소 크기 ④ 스토리지 클래스 |
| `create-batch-job-with-inventory.sh` | 소스 버킷에 S3 Inventory(Daily) 설정 + 전체 객체 목록으로 즉시 manifest 생성 |
| `check-replication-status.sh` | 소스 객체별 `ReplicationStatus`, 버전 ID, 대상 버킷 존재 여부 및 통계 출력 |

```bash
./create-batch-job.sh
```

대용량 버킷의 manifest 작성 방법은 [BATCH_JOB_EXAMPLES.md](./BATCH_JOB_EXAMPLES.md) 를 참고하세요.

### 4. Job 상태 확인

```bash
JOB_ID="<create-batch-job.sh 출력의 Job ID>"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

aws s3control describe-job \
  --account-id $ACCOUNT_ID \
  --job-id $JOB_ID \
  --region ap-northeast-2
```

### 5. 복제 결과 / 리포트 확인

```bash
./check-replication-status.sh

REPORT_BUCKET=$(terraform output -raw report_bucket)
aws s3 ls s3://$REPORT_BUCKET/batch-reports/ --recursive
aws s3 cp s3://$REPORT_BUCKET/batch-reports/ ./reports --recursive
```

### 6. 정리

```bash
terraform destroy   # force_destroy = true 이므로 객체가 남아 있어도 삭제됨
```

## Batch Job 설정 (batch-job.json)

| 필드 | 값 | 설명 |
|------|----|------|
| `AccountId` | 현재 계정 | Job 을 만드는 계정 |
| `ConfirmationRequired` | `false` | 생성 즉시 실행 |
| `Operation.S3ReplicateObject` | `{}` | **파라미터가 없는 작업**입니다. 대상 버킷·스토리지 클래스·KMS 는 소스 버킷의 **복제 규칙**(`replication_rules`)을 그대로 따릅니다. 복제 규칙이 없으면 Job 이 실패합니다 |
| `Manifest.Spec.Format` | `S3BatchOperations_CSV_20180820` | CSV manifest |
| `Manifest.Spec.Fields` | `["Bucket", "Key"]` | CSV 컬럼 |
| `Manifest.Location` | 리포트 버킷 `manifests/*.csv` + ETag | manifest 위치 |
| `Priority` | `10` | 숫자가 클수록 먼저 실행 |
| `RoleArn` | `terraform output replication_role_arn` | 모듈이 만든 Role |
| `Report` | 리포트 버킷, prefix `batch-reports`, `AllTasks` | 전체 작업 결과 리포트 (`FailedTasksOnly` 로 실패만 저장 가능) |

## 주의사항

- 복제를 쓰려면 소스와 대상 버킷 모두 **버전 관리**가 켜져 있어야 합니다.
- Batch Replication(`S3ReplicateObject`)은 소스 버킷의 복제 규칙을 사용하므로, `terraform apply` 로 복제 규칙을 먼저 만든 뒤 Job 을 실행하세요.
- 이미 복제된 객체(`ReplicationStatus = COMPLETED`)를 다시 manifest 에 넣으면 대상에 같은 버전이 다시 쓰입니다. `check-replication-status.sh` 로 먼저 확인하세요.
- RTC 가 필요하면 `destination.replication_time` 과 `destination.metrics` 를 **함께** `true` 로 설정하세요 (하나만 켜면 plan 단계에서 오류). 둘 다 추가 요금이 발생합니다.
- `force_destroy = true` 는 PoC 용입니다. 운영 환경에서는 제거하세요.
