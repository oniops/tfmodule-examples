# custom-policy — 사용자 정의 버킷 정책 병합

## 목적

모듈이 제공하는 기본 정책(HTTPS 강제)과 **사용자가 직접 작성한 정책 statement** 를 하나의 버킷 정책으로 합치는 예제입니다.
`attach_custom_policy` 에 HCL 리스트로 statement 를 넘기면, 모양이 서로 다른 statement 도 그대로 병합됩니다.

## 주요 특징

| 항목 | 설정 | 설명 |
|------|------|------|
| 버킷 이름 | `demo-an2p-demo-s3` | `bucket = "${s3_bucket_prefix}-demo-s3"` — context 의 접두어로 전체 이름을 직접 구성 |
| 객체 소유권 | `BucketOwnerEnforced` | ACL 비활성화, 버킷 소유자가 모든 객체 소유 |
| 암호화 | SSE-S3 (`AES256`) | 모듈 기본값 |
| 기본 정책 | HTTPS 강제 | `attach_deny_insecure_transport_policy = true` |
| 사용자 정책 | statement 2개 | `attach_custom_policy = local.attach_custom_policy` |

### 병합되는 사용자 정의 statement

| Sid | 허용 대상 | 권한 | 모양 |
|-----|-----------|------|------|
| `AllowCloudFrontDistributeForWhiteLabel` | `cloudfront.amazonaws.com` (같은 계정의 배포만, `aws:SourceArn` 조건) | `s3:GetObject` | Action 이 문자열, Resource 1개 |
| `AllowELBLogWrite` | `logdelivery.elasticloadbalancing.amazonaws.com`, `cloudwatch.amazonaws.com` | `s3:PutObject`, `s3:PutObjectAcl` | Action·Resource·Principal 이 리스트 |

최종 버킷 정책은 `terraform plan` 의 `aws_s3_bucket_policy` 리소스에서 확인할 수 있습니다. 코드에서 쓰려면 모듈 output `module.s3Pols.bucket_policy` 를 참조하세요 (이 예제에는 `outputs.tf` 가 없음).

### 생성되는 리소스 (5개)

`aws_s3_bucket`, `aws_s3_bucket_public_access_block`, `aws_s3_bucket_ownership_controls`, `aws_s3_bucket_server_side_encryption_configuration`, `aws_s3_bucket_policy`

## 프로비저닝

### 사전 준비

- Terraform `>= 1.7.0`, AWS 자격 증명 (`AWS_PROFILE`)
- 모듈 태그 `v1.8.0`

### 배포

```bash
cd tfmodule-aws-s3/custom-policy
export AWS_PROFILE=<profile>

terraform init
terraform plan     # Plan: 5 to add — aws_s3_bucket_policy 의 policy 에서 statement 3개 확인
terraform apply
```

### 확인

```bash
BUCKET=demo-an2p-demo-s3
aws s3api get-bucket-policy --bucket $BUCKET --query Policy --output text | jq '.Statement[].Sid'
```

HTTPS 강제 statement 와 사용자 정의 statement 2개가 함께 보여야 합니다.

### 삭제

```bash
terraform destroy   # 버킷이 비어 있어야 함 (force_destroy 미설정)
```

## 주의사항

- `attach_custom_policy` 는 HCL 리스트, 단일 statement 객체, JSON 문자열을 모두 받습니다. HCL 리스트가 가장 읽기 쉽습니다.
- 사용자 정의 statement 의 `Resource` 에 버킷 ARN 을 직접 적을 때는 실제 버킷 이름과 같아야 합니다. 이 예제는 `local.s3_bucket_prefix` 로 버킷 이름과 같은 값을 만들어 씁니다.
- 퍼블릭 액세스 차단이 켜져 있어도 특정 AWS 서비스 principal 에 대한 허용은 막지 않습니다. 버킷을 퍼블릭으로 열려면 `block_public_policy` 등을 따로 조정해야 합니다.
