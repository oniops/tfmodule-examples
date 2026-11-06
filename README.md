# tfmodule-examples
terraform module 을 사용하는 샘플 프로젝트 입니다. 

## 개요

[oniops](https://github.com/oniops) 의 Terraform 모듈을 실제로 어떻게 호출하는지 보여 주는 예제 모음입니다.
각 예제 디렉터리는 독립된 Terraform 루트 모듈이며, 디렉터리 안에서 바로 `terraform init` / `apply` 할 수 있습니다.

현재는 [tfmodule-aws-s3](https://github.com/oniops/tfmodule-aws-s3) `v1.8.0` 예제만 포함되어 있습니다.
모든 예제는 [tfmodule-context](https://github.com/oniops/tfmodule-context) `v1.3.6` 으로 공통 context(프로젝트·리전·환경·태그 정보)를 만들고, 이를 S3 모듈에 넘깁니다.

## 예제 목록

| 예제 | 내용 |
|------|------|
| [basic](./tfmodule-aws-s3/basic/HELP.md) | 기본 S3 버킷: 퍼블릭 액세스 차단, HTTPS 강제 정책, GLACIER·DEEP_ARCHIVE 전환 lifecycle |
| [lifecycle](./tfmodule-aws-s3/lifecycle/HELP.md) | prefix·태그 필터 기반 lifecycle 규칙, 미완료 멀티파트 업로드 정리, SSE-KMS 암호화 |
| [cloudtrail](./tfmodule-aws-s3/cloudtrail/HELP.md) | Object Lock(COMPLIANCE)을 켠 CloudTrail 중앙 로그 버킷과 CloudTrail 전용 버킷 정책 |
| [custom-policy](./tfmodule-aws-s3/custom-policy/HELP.md) | 모듈 기본 정책(HTTPS 강제)과 사용자 정의 statement(CloudFront, ELB 로그) 병합 |
| [replica-basic](./tfmodule-aws-s3/replica-basic/HELP.md) | 서울(`ap-northeast-2`) → 도쿄(`ap-northeast-1`) 기본 Cross-Region 복제 |
| [replica-filtered-kms](./tfmodule-aws-s3/replica-filtered-kms/HELP.md) | `sensitive/` prefix 의 SSE-KMS 암호화 객체만 복제, 대상 리전 KMS 키로 재암호화 |
| [replica-multiple](./tfmodule-aws-s3/replica-multiple/HELP.md) | 하나의 소스 버킷에서 prefix 별로 두 대상 버킷에 복제 |
| [replica-reporting](./tfmodule-aws-s3/replica-reporting/HELP.md) | 복제 규칙 + 기존 객체용 S3 Batch Replication, Batch Job 리포트 버킷, Job 생성·상태 확인 스크립트 |

예제별 설정, 생성되는 리소스, 확인 방법, 주의사항은 각 디렉터리의 `HELP.md` 에 있습니다.

## 요구 사항

- Terraform `>= 1.7.0`
- AWS provider `hashicorp/aws >= 6.0.0`
- S3 버킷, 버킷 정책, IAM Role/Policy(복제 예제)를 만들 수 있는 AWS 자격 증명
- `replica-reporting` 의 셸 스크립트: AWS CLI, bash

모듈은 `git::https://github.com/...?ref=<tag>` 로 받아 오므로 `terraform init` 시 GitHub 에 접근할 수 있어야 합니다.

## 사용법

예제 디렉터리로 이동해 배포합니다. AWS provider 는 `AWS_PROFILE` 등 환경 변수의 자격 증명을 사용하고, 리전은 context 값(`ap-northeast-2`)에서 가져옵니다.

```bash
cd tfmodule-aws-s3/basic
export AWS_PROFILE=<profile>

terraform init
terraform plan
terraform apply
```

삭제:

```bash
terraform destroy
```

- 복제 예제(`replica-*`)는 `aws.replica` provider alias 로 대상 버킷을 `ap-northeast-1` 에 만듭니다.
- 버킷 이름에는 context 가 만든 접두어가 붙습니다. 예: `bucket_name = "exr101-basic-replica-source"` → `demo-an2p-exr101-basic-replica-source-s3`
- S3 버킷 이름은 모든 AWS 계정에서 고유해야 하므로, 이름이 겹치면 `main.tf` 의 `bucket_name` 이나 `module "ctx"` 의 `project` 값을 바꾸세요.
- `lifecycle` 과 복제 예제(`replica-*`)의 버킷은 `force_destroy = true` 라 객체가 남아 있어도 삭제됩니다. `basic`, `cloudtrail`, `custom-policy` 는 버킷을 먼저 비워야 `destroy` 가 성공합니다 (`cloudtrail` 은 Object Lock 보존 기간 동안 객체를 지울 수 없음).

## 프로젝트 구조

```
tfmodule-examples/
└── tfmodule-aws-s3/          # tfmodule-aws-s3 모듈 예제
    ├── basic/
    ├── cloudtrail/
    ├── custom-policy/
    ├── lifecycle/
    ├── replica-basic/
    ├── replica-filtered-kms/
    ├── replica-multiple/
    └── replica-reporting/
```

각 예제 디렉터리 구성:

| 파일 | 역할 |
|------|------|
| `main.tf` | `module "ctx"`(context) 와 S3 모듈 호출 |
| `providers.tf` | Terraform·AWS provider 버전, provider 설정 (복제 예제는 `aws.replica` alias 포함) |
| `data.tf` | KMS 키 alias(`alias/aws/s3`) 조회 — KMS 를 쓰는 예제에만 있음 |
| `variables.tf` | `mfa_serial`, `mfa_token` 변수 선언 — 예제 코드에서는 사용하지 않음 |
| `outputs.tf` | 스크립트가 읽는 버킷 이름·Role ARN — `replica-reporting` 에만 있음 |
| `HELP.md` | 예제 설명과 배포·확인·삭제 절차 |

## 라이선스

[The Unlicense](./LICENSE) — 퍼블릭 도메인으로 공개되어 있습니다.
