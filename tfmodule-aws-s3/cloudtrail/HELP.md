# cloudtrail — CloudTrail 로그 보관 버킷 (Object Lock)

## 목적

여러 계정·리전의 CloudTrail 로그를 한곳에 모으는 **중앙 로그 버킷**을 만드는 예제입니다.
Object Lock 으로 로그가 지워지거나 바뀌지 않게 보호하고, CloudTrail 서비스만 로그를 쓸 수 있도록 버킷 정책을 예제에서 직접 붙입니다.

## 주요 특징

| 항목 | 설정 | 설명 |
|------|------|------|
| 버킷 이름 | `demo-an2p-central-cloudtrail-s3` | `bucket_name = "central-cloudtrail"` + context 접두어 |
| 객체 소유권 | `BucketOwnerPreferred` | 모듈이 버킷 소유자 FULL_CONTROL ACL 생성 |
| Object Lock | 사용 (`object_lock_enabled = true`) | 모듈 기본값: **`COMPLIANCE` 모드, 365일 보존** |
| 암호화 | SSE-S3 (`AES256`) | 모듈 기본값 |
| 버킷 정책 | 예제의 `aws_s3_bucket_policy.policy` | 모듈 정책 기능은 쓰지 않고 `aws_iam_policy_document` 로 직접 작성 |

### 버킷 정책 (예제에서 작성)

| Sid | 효과 | 내용 |
|-----|------|------|
| `AWSCloudTrailAclCheck` | Allow | CloudTrail 이 버킷 ACL 조회 (`s3:GetBucketAcl`) |
| `AWSCloudTrailWrite` | Allow | CloudTrail 이 `bucket-owner-full-control` ACL 로 로그 쓰기 |
| `Deny unencrypted object uploads` | Deny | `x-amz-server-side-encryption` 이 `aws:kms` 가 아닌 업로드 거부 |

### 생성되는 리소스 (7개)

모듈: `aws_s3_bucket`, `aws_s3_bucket_public_access_block`, `aws_s3_bucket_ownership_controls`, `aws_s3_bucket_acl`, `aws_s3_bucket_server_side_encryption_configuration`, `aws_s3_bucket_object_lock_configuration`
예제: `aws_s3_bucket_policy.policy`

## 프로비저닝

### 사전 준비

- Terraform `>= 1.7.0`, AWS 자격 증명 (`AWS_PROFILE`)
- 모듈 태그 `v1.8.0`
- **아래 주의사항의 Object Lock 보존 기간을 먼저 확인하세요.**

### 배포

```bash
cd tfmodule-aws-s3/cloudtrail
export AWS_PROFILE=<profile>

terraform init
terraform plan     # Plan: 7 to add
terraform apply
```

### 확인

```bash
BUCKET=demo-an2p-central-cloudtrail-s3

aws s3api get-object-lock-configuration --bucket $BUCKET
aws s3api get-bucket-policy --bucket $BUCKET --query Policy --output text | jq .
```

### CloudTrail 연결

이 예제는 **버킷만** 만들고 Trail 은 만들지 않습니다. Trail 을 만들 때는 다음을 지키세요.

- 버킷 정책이 `aws:kms` 가 아닌 업로드를 거부하므로, Trail 에 **SSE-KMS 키(`kms_key_id`)를 반드시 지정**해야 로그가 쌓입니다. KMS 키 정책에서 CloudTrail 의 암호화를 허용해야 합니다.
- 다른 계정의 Trail 이 쓰게 하려면 `AWSCloudTrailWrite` 의 `resources` 를 `AWSLogs/<계정 ID>/*` 단위로 열어 주세요.

## 주의사항

- **Object Lock `COMPLIANCE` 365일:** 이 버킷에 쓴 객체는 **루트 계정을 포함해 누구도 365일 동안 삭제·덮어쓰기할 수 없고**, 보존 기간을 줄일 수도 없습니다. 테스트 목적이라면 `object_lock_mode = "GOVERNANCE"` 와 짧은 `object_lock_days` 를 지정하세요.
- Object Lock 은 버킷을 만들 때만 켤 수 있고, 켠 뒤에는 끌 수 없습니다. Object Lock 버킷은 버전 관리가 자동으로 켜집니다.
- `force_destroy` 를 설정하지 않았고, 보존 중인 객체는 지울 수 없으므로 **객체가 쓰인 뒤에는 `terraform destroy` 로 버킷을 삭제할 수 없습니다**. 빈 상태일 때만 삭제됩니다.
