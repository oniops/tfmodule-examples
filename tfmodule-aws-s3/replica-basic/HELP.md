# replica-basic — 기본 Cross-Region 복제

## 목적

소스 버킷(서울, `ap-northeast-2`)의 **모든 신규 객체를 다른 리전(도쿄, `ap-northeast-1`)의 대상 버킷으로 자동 복제**하는 예제입니다.
재해 복구(DR)용 백업 버킷을 만드는 가장 기본적인 구성이며, 복제에 필요한 IAM Role 은 모듈이 자동으로 만듭니다.

## 주요 특징

| 버킷 | 이름 | 리전 | 설정 |
|------|------|------|------|
| 소스 (`module.source`) | `demo-an2p-exr101-basic-replica-source-s3` | ap-northeast-2 | 버전 관리, 복제 규칙, SSE-S3 |
| 대상 (`module.target`) | `demo-an2p-exr101-basic-replica-target-s3` | ap-northeast-1 (`aws.replica`) | 버전 관리, SSE-S3 |

### 복제 규칙

| 규칙 ID | priority | 필터 | 삭제 마커 복제 | 대상 |
|---------|----------|------|----------------|------|
| `basic-replica-rule` | 0 | 없음 (모든 객체) | 안 함 | 대상 버킷, 스토리지 클래스는 원본과 동일 |

- 복제는 소스와 대상 버킷 모두 **버전 관리가 켜져 있어야** 합니다.
- 모듈이 복제용 IAM Role(`demoExr101BasicReplicaSourceS3CrrRole`)과 Policy 를 만들어 연결합니다.
- 규칙을 만든 **이후에 올라온 객체만** 복제됩니다. 기존 객체는 Batch Replication 으로 따로 복제해야 합니다 (`replica-reporting` 예제 참고).

### 생성되는 리소스 (16개)

- 소스 버킷 7개: 버킷, 퍼블릭 액세스 차단, 소유권, ACL, 암호화, 버전 관리, 복제 설정
- 대상 버킷 6개: 버킷, 퍼블릭 액세스 차단, 소유권, ACL, 암호화, 버전 관리
- 복제 IAM 3개: `aws_iam_role`, `aws_iam_policy`, `aws_iam_role_policy_attachment`

## 프로비저닝

### 사전 준비

- Terraform `>= 1.7.0`, AWS 자격 증명 (`AWS_PROFILE`)
- S3 버킷과 IAM Role/Policy 를 만들 수 있는 권한
- 모듈 태그 `v1.8.0`
- 대상 리전은 `providers.tf` 의 `local.replica_region` 으로 바꿀 수 있습니다.

### 배포

```bash
cd tfmodule-aws-s3/replica-basic
export AWS_PROFILE=<profile>

terraform init
terraform plan     # Plan: 16 to add
terraform apply
```

대상 버킷이 먼저 만들어지도록 소스 모듈에 `depends_on = [module.target]` 이 걸려 있습니다.

### 복제 확인

```bash
SRC=demo-an2p-exr101-basic-replica-source-s3
DST=demo-an2p-exr101-basic-replica-target-s3

echo "hello" > test.txt
aws s3 cp test.txt s3://$SRC/test.txt

# 복제 상태: PENDING → COMPLETED (보통 수 초~수 분)
aws s3api head-object --bucket $SRC --key test.txt --query ReplicationStatus

# 대상 버킷 (도쿄)
aws s3 ls s3://$DST/ --region ap-northeast-1
```

### 삭제

```bash
terraform destroy   # 두 버킷 모두 force_destroy = true
```

## 주의사항

- 삭제 마커 복제를 끈 상태(`delete_marker_replication = false`)라, 소스에서 객체를 지워도 대상의 객체는 남습니다.
- RTC(15분 내 복제 보장)와 복제 메트릭은 쓰지 않습니다. 필요하면 `destination.replication_time = true`, `destination.metrics = true` 를 함께 지정하세요 (추가 요금).
- 리전 간 복제는 데이터 전송 요금이 발생합니다.
