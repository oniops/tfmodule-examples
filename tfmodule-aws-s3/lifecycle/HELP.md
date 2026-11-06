# lifecycle — Lifecycle 규칙 (prefix·태그 필터, 미완료 멀티파트 정리)

## 목적

`lifecycle_rules` 로 **경로(prefix)와 태그에 따라 객체 보관 기간을 다르게** 관리하고, 업로드가 중단된 **미완료 멀티파트 업로드를 자동 정리**하는 예제입니다.
규칙은 `map` 의 key 가 규칙 ID 가 되므로, 규칙 순서를 바꾸거나 일부를 지워도 다른 규칙에는 영향이 없습니다.

## 주요 특징

| 항목 | 설정 | 설명 |
|------|------|------|
| 버킷 이름 | `demo-an2p-ex01-hello-lifecycle-s3` | `bucket_name` + context 접두어 |
| 객체 소유권 | `ObjectWriter` | 모듈이 ACL 생성 |
| 암호화 | SSE-KMS (`aws:kms`) + Bucket Key | AWS 관리형 키 `alias/aws/s3` (`data.tf` 에서 조회) |
| 버전 관리 | 사용 안 함 | |

### Lifecycle 규칙

| 규칙 ID | 대상 (filter) | 동작 |
|---------|---------------|------|
| `days-7-rule` | `reports/` prefix | 7일 후 객체 삭제 |
| `days-30-rule` | `logs/` prefix **and** 태그 `Porject=demo`, `ProductType=EC2` | 30일 후 객체 삭제 |
| `abort-incomplete-mpu-7d` | 버킷 전체 | 시작 후 7일이 지난 미완료 멀티파트 업로드 삭제 |
| `uploads-abort-mpu-7d` | `uploads/` prefix | 시작 후 7일이 지난 미완료 멀티파트 업로드 삭제 |

- 조건이 2개 이상이면 `filter.and` 로 묶습니다 (`days-30-rule`).
- 미완료 멀티파트 업로드는 객체 목록에 보이지 않지만 저장 요금이 계속 나옵니다. `abort_incomplete_multipart_upload_days` 로 정리합니다.
- 버킷 전체 규칙이 있으면 `uploads/` 도 이미 포함됩니다. 이 예제는 두 가지 작성 방법을 함께 보여 주기 위한 것이며, 실제로는 둘 중 하나만 써도 됩니다. 일수가 다르면 겹치는 업로드에는 짧은 쪽이 적용됩니다.

### 생성되는 리소스 (6개)

`aws_s3_bucket`, `aws_s3_bucket_public_access_block`, `aws_s3_bucket_ownership_controls`, `aws_s3_bucket_acl`, `aws_s3_bucket_server_side_encryption_configuration`, `aws_s3_bucket_lifecycle_configuration` (규칙 4개)

## 프로비저닝

### 사전 준비

- Terraform `>= 1.7.0`, AWS 자격 증명 (`AWS_PROFILE`)
- 모듈 태그 `v1.8.0` (`abort_incomplete_multipart_upload_days` 는 v1.8.0 부터 지원)

### 배포

```bash
cd tfmodule-aws-s3/lifecycle
export AWS_PROFILE=<profile>

terraform init
terraform plan     # Plan: 6 to add — lifecycle 규칙 4개 확인
terraform apply
```

### 확인

```bash
BUCKET=demo-an2p-ex01-hello-lifecycle-s3

# 규칙 4개와 AbortIncompleteMultipartUpload.DaysAfterInitiation = 7 확인
aws s3api get-bucket-lifecycle-configuration --bucket $BUCKET

# 현재 남아 있는 미완료 멀티파트 업로드 목록
aws s3api list-multipart-uploads --bucket $BUCKET
```

Lifecycle 규칙은 S3 가 하루 한 번 정도 비동기로 적용하므로, 만료·정리 결과가 바로 보이지 않을 수 있습니다.

### 삭제

```bash
terraform destroy   # force_destroy = true 이므로 객체가 남아 있어도 삭제됨
```

## 주의사항

- `abort_incomplete_multipart_upload_days` 는 **태그 기반 필터(`filter.tag`, `filter.and.tags`)와 함께 쓸 수 없습니다**. 함께 지정하면 `terraform plan` 단계에서 오류가 납니다.
- 규칙에 없는 속성 이름(오타 등)은 Terraform 이 오류 없이 무시합니다. plan 결과에서 의도한 블록이 렌더링되는지 확인하세요.
- `days-30-rule` 의 태그 키 `Porject` 는 예제 값 그대로입니다. 실제 사용 시 객체에 붙인 태그 키와 정확히 같아야 규칙이 적용됩니다.
