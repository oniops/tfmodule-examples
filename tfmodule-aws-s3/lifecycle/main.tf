module "ctx" {
  source = "git::https://github.com/oniops/tfmodule-context.git?ref=v1.3.6"
  context = {
    project     = "demo"
    region      = "ap-northeast-2"
    environment = "PoC"
    customer    = "My Customer"
    department  = "DevOps"
    team        = "DevOps"
    owner       = "me@example.com"
    domain      = "example.com"
    pri_domain  = "example.internal"
  }
}

module "s3Demo" {
  source                  = "git::https://github.com/oniops/tfmodule-aws-s3.git?ref=v1.8.0"
  context                 = module.ctx.context
  bucket_name             = "ex01-hello-lifecycle"
  object_ownership        = "ObjectWriter"
  sse_algorithm           = "aws:kms"
  kms_master_key_id       = data.aws_kms_alias.origin.target_key_arn
  bucket_key_enabled      = true
  enable_bucket_lifecycle = true
  lifecycle_rules = {
    "days-7-rule" = {
      filter = {
        prefix = "reports/"
      }
      expiration_days = 7
    }

    "days-30-rule" = {
      filter = {
        and = {
          prefix = "logs/"
          tags = {
            Porject     = "demo"
            ProductType = "EC2"
          }
        }
      }
      expiration_days = 30
    }

    # 버킷 전체: 시작 후 7일이 지나도 완료되지 않은 멀티파트 업로드 삭제
    "abort-incomplete-mpu-7d" = {
      abort_incomplete_multipart_upload_days = 7
    }

    # prefix 기준: uploads/ 아래의 미완료 멀티파트 업로드만 7일 후 삭제
    # (버킷 전체 규칙과 함께 쓰면 uploads/ 는 두 규칙에 모두 해당됨 - 일수가 다르면 짧은 쪽이 적용)
    "uploads-abort-mpu-7d" = {
      filter = {
        prefix = "uploads/"
      }
      abort_incomplete_multipart_upload_days = 7
    }
  }

  force_destroy = true
}
