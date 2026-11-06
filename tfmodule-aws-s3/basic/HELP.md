# basic — 기본 S3 버킷

## 목적

`tfmodule-aws-s3` 모듈로 가장 단순한 형태의 S3 버킷을 만드는 예제입니다.
퍼블릭 액세스 차단, 기본 암호화, HTTPS 강제 정책, 오래된 객체를 저렴한 스토리지로 옮기는 lifecycle 규칙까지, 일반 버킷에 필요한 최소 구성을 보여 줍니다.

## 주요 특징

| 항목 | 설정 | 설명 |
|------|------|------|
| 버킷 이름 | `demo-an2p-exam-basic-s3` | `bucket_name = "exam-basic"` + context 접두어 |
| 객체 소유권 | `ObjectWriter` | 업로드한 계정이 객체를 소유 |
| 퍼블릭 액세스 | 모두 차단 | 모듈 기본값 |
| 암호화 | SSE-S3 (`AES256`) | 모듈 기본값 |
| 버킷 정책 | HTTPS 강제 | `attach_deny_insecure_transport_policy = true` — HTTP 요청 거부 |
| Lifecycle | `default-rule` | 버킷 전체 객체를 180일 후 `GLACIER`, 365일 후 `DEEP_ARCHIVE` 로 전환, 730일 후 삭제 |
| 버전 관리 | 사용 안 함 | |

버킷 정책을 붙이면 모듈은 ACL 리소스를 만들지 않습니다 (정책과 ACL 충돌 방지).

### 생성되는 리소스 (6개)

`aws_s3_bucket`, `aws_s3_bucket_public_access_block`, `aws_s3_bucket_ownership_controls`, `aws_s3_bucket_server_side_encryption_configuration`, `aws_s3_bucket_policy`, `aws_s3_bucket_lifecycle_configuration`

## 프로비저닝

### 사전 준비

- Terraform `>= 1.7.0`, AWS 자격 증명 (`AWS_PROFILE` 또는 환경 변수)
- 버킷을 만들 수 있는 IAM 권한 (S3 버킷·정책·lifecycle 설정)
- 모듈 태그 `v1.8.0` 이 `oniops/tfmodule-aws-s3` 에 있어야 `terraform init` 이 성공합니다.

### 배포

```bash
cd tfmodule-aws-s3/basic
export AWS_PROFILE=<profile>

terraform init
terraform plan     # Plan: 6 to add
terraform apply
```

리전은 context(`ap-northeast-2`)에서 가져옵니다.

### 확인

```bash
BUCKET=demo-an2p-exam-basic-s3

aws s3api get-bucket-lifecycle-configuration --bucket $BUCKET
aws s3api get-bucket-policy --bucket $BUCKET --query Policy --output text | jq .
aws s3api get-bucket-encryption --bucket $BUCKET

# HTTP 요청은 거부되어야 함 (정책 확인)
aws s3 ls s3://$BUCKET --endpoint-url http://s3.ap-northeast-2.amazonaws.com   # AccessDenied
```

### 삭제

```bash
terraform destroy
```

`force_destroy` 를 설정하지 않았으므로 버킷에 객체가 남아 있으면 삭제가 실패합니다. 먼저 `aws s3 rm s3://demo-an2p-exam-basic-s3 --recursive` 로 비우세요.

## 주의사항

- S3 버킷 이름은 **모든 AWS 계정에서 겹칠 수 없습니다**. `demo-an2p-exam-basic-s3` 이 이미 쓰이고 있으면 `bucket_name` 값이나 `module "ctx"` 의 `project` 값을 바꾸세요. 접두어 없이 전체 이름을 직접 지정하려면 `bucket_name` 대신 `bucket` 을 쓰면 됩니다.
- `GLACIER`·`DEEP_ARCHIVE` 로 전환된 객체는 읽기 전에 복원(restore)이 필요하고, 최소 보관 기간(90일/180일) 요금이 있습니다.
- `variables.tf` 의 `mfa_serial`, `mfa_token` 은 이 예제에서 사용하지 않습니다.
