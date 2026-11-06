# replica-filtered-kms — prefix 필터 + KMS 암호화 객체 복제

## 목적

소스 버킷에서 **`sensitive/` 경로에 있고 SSE-KMS 로 암호화된 객체만** 다른 리전의 대상 버킷으로 복제하는 예제입니다.
민감 데이터만 골라 DR 리전에 보관하면서, 대상 리전에서도 KMS 키로 다시 암호화해 저장하는 구성을 보여 줍니다.

## 주요 특징

| 버킷 | 이름 | 리전 | 암호화 |
|------|------|------|--------|
| 소스 (`module.source`) | `demo-an2p-exr201-filtered-kms-source-s3` | ap-northeast-2 | SSE-KMS — 소스 리전의 `alias/aws/s3` |
| 대상 (`module.target`) | `demo-an2p-exr201-filtered-kms-target-s3` | ap-northeast-1 (`aws.replica`) | 버킷 기본값은 SSE-S3, 복제본은 대상 리전의 `alias/aws/s3` 로 암호화 |

두 KMS 키는 `data.tf` 의 `aws_kms_alias` 로 각 리전에서 조회합니다.

### 복제 규칙

| 규칙 ID | priority | 필터 | 복제 대상 객체 | 대상 암호화 |
|---------|----------|------|----------------|-------------|
| `filtered-kms-replica` | 0 | `sensitive/` prefix | `sse_kms_encrypted_objects = true` — **SSE-KMS 로 암호화된 객체만** | `replica_kms_key_id` = 대상 리전 `alias/aws/s3` |

| 업로드 예 | 복제 여부 |
|-----------|-----------|
| `sensitive/a.txt` (SSE-KMS) | 복제됨 |
| `sensitive/b.txt` (SSE-S3) | 복제 안 됨 |
| `public/c.txt` (SSE-KMS) | 복제 안 됨 (prefix 불일치) |

- 모듈이 만드는 복제 IAM Policy 에 소스 키 복호화(`kms:Decrypt`)와 대상 키 암호화(`kms:Encrypt`, `kms:GenerateDataKey`) 권한이 자동으로 들어갑니다.
- `replica_kms_key_id` 를 지정하면 `sse_kms_encrypted_objects = true` 가 필수입니다. 빠지면 `terraform plan` 단계에서 오류가 납니다.

### 생성되는 리소스 (16개)

- 소스 버킷 7개 (복제 설정 포함), 대상 버킷 6개, 복제 IAM 3개 (`aws_iam_role`, `aws_iam_policy`, `aws_iam_role_policy_attachment`)

## 프로비저닝

### 사전 준비

- Terraform `>= 1.7.0`, AWS 자격 증명 (`AWS_PROFILE`)
- S3, IAM 권한과 두 리전의 KMS 키 조회 권한
- 모듈 태그 `v1.8.0`

### 배포

```bash
cd tfmodule-aws-s3/replica-filtered-kms
export AWS_PROFILE=<profile>

terraform init
terraform plan     # Plan: 16 to add — encryption_configuration 의 키가 ap-northeast-1 키인지 확인
terraform apply
```

### 복제 확인

```bash
SRC=demo-an2p-exr201-filtered-kms-source-s3
DST=demo-an2p-exr201-filtered-kms-target-s3

echo "secret" > a.txt
aws s3 cp a.txt s3://$SRC/sensitive/a.txt                      # 버킷 기본값 SSE-KMS 로 암호화
aws s3 cp a.txt s3://$SRC/sensitive/b.txt --sse AES256         # SSE-S3 → 복제 대상 아님

aws s3api head-object --bucket $SRC --key sensitive/a.txt --query ReplicationStatus   # COMPLETED
aws s3api head-object --bucket $SRC --key sensitive/b.txt --query ReplicationStatus   # null

aws s3api head-object --bucket $DST --key sensitive/a.txt --region ap-northeast-1 \
  --query '[ServerSideEncryption,SSEKMSKeyId]'
```

### 삭제

```bash
terraform destroy   # 두 버킷 모두 force_destroy = true
```

## 주의사항

- 이 예제는 AWS 관리형 키(`alias/aws/s3`)를 씁니다. **다른 계정으로 복제**하거나 키 정책을 직접 관리해야 한다면 고객 관리형 키(CMK)를 쓰고, 키 정책에서 복제 Role 의 사용을 허용하세요.
- `bucket_key_enabled = false` 입니다. 객체가 많으면 Bucket Key 를 켜 KMS 요청 비용을 줄일 수 있습니다.
- 삭제 마커는 복제하지 않습니다 (`delete_marker_replication = false`).
