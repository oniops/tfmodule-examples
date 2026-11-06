# replica-multiple — 하나의 소스에서 여러 대상으로 복제

## 목적

하나의 소스 버킷에서 **경로(prefix)에 따라 서로 다른 대상 버킷으로 복제**하는 예제입니다.
`first/` 는 첫 번째 대상으로, `second/` 의 KMS 암호화 객체는 두 번째 대상으로 보내는 식으로, 데이터 종류별로 보관 위치를 나눌 때 쓰는 구성입니다.

## 주요 특징

| 버킷 | 이름 | 리전 | 설정 |
|------|------|------|------|
| 소스 (`module.source`) | `demo-an2p-exr301-multiple-replica-source-s3` | ap-northeast-2 | 버전 관리, 복제 규칙 2개, SSE-KMS(`alias/aws/s3`) + Bucket Key |
| 첫 번째 대상 (`module.targetFirst`) | `demo-an2p-exr301-multiple-replica-first-target-s3` | ap-northeast-1 | 버전 관리, SSE-S3 |
| 두 번째 대상 (`module.targetSecond`) | `demo-an2p-exr301-multiple-replica-second-target-s3` | ap-northeast-1 | 버전 관리, SSE-S3 |

### 복제 규칙

| 규칙 ID | priority | 필터 | 복제 대상 객체 | 대상 버킷 | 대상 암호화 |
|---------|----------|------|----------------|-----------|-------------|
| `first-rule` | 0 | `first/` | 조건 없음 | 첫 번째 대상 | 대상 버킷 기본값 |
| `second-rule` | 10 | `second/` | SSE-KMS 로 암호화된 객체만 | 두 번째 대상 | 대상 리전 `alias/aws/s3` |

- `priority` 는 규칙마다 달라야 합니다. 같은 객체가 두 규칙에 모두 해당하면 숫자가 큰 규칙이 적용됩니다.
- 복제 IAM Policy 에는 두 대상 버킷과 대상 KMS 키, 소스 KMS 키 권한이 모두 들어갑니다.

### 생성되는 리소스 (22개)

- 소스 버킷 7개 (복제 설정 포함), 대상 버킷 6개 × 2, 복제 IAM 3개

## 프로비저닝

### 사전 준비

- Terraform `>= 1.7.0`, AWS 자격 증명 (`AWS_PROFILE`)
- S3, IAM 권한과 두 리전의 KMS 키 조회 권한
- 모듈 태그 `v1.8.0`

### 배포

```bash
cd tfmodule-aws-s3/replica-multiple
export AWS_PROFILE=<profile>

terraform init
terraform plan     # Plan: 22 to add — rule 2개의 priority·filter·대상 확인
terraform apply
```

### 복제 확인

```bash
SRC=demo-an2p-exr301-multiple-replica-source-s3
DST1=demo-an2p-exr301-multiple-replica-first-target-s3
DST2=demo-an2p-exr301-multiple-replica-second-target-s3

echo "1" > one.txt && aws s3 cp one.txt s3://$SRC/first/one.txt
echo "2" > two.txt && aws s3 cp two.txt s3://$SRC/second/two.txt   # 버킷 기본값 SSE-KMS

aws s3 ls s3://$DST1/first/  --region ap-northeast-1
aws s3 ls s3://$DST2/second/ --region ap-northeast-1
```

### 삭제

```bash
terraform destroy   # 세 버킷 모두 force_destroy = true
```

## 주의사항

- `first/`·`second/` 어디에도 해당하지 않는 객체는 복제되지 않습니다.
- `second-rule` 은 SSE-KMS 객체만 복제합니다. `second/` 에 SSE-S3 로 올린 객체는 복제되지 않습니다.
- 대상이 여러 개면 복제 요청·전송 요금도 대상 수만큼 늘어납니다.
