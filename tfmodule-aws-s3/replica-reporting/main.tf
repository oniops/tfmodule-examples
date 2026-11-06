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

# 복제 대상 버킷 (다른 리전)
module "target" {
  source = "git::https://github.com/oniops/tfmodule-aws-s3.git?ref=v1.8.0"
  providers = {
    aws = aws.replica
  }
  context           = module.ctx.context
  bucket_name       = "exr401-report-replica-target"
  object_ownership  = "ObjectWriter"
  enable_versioning = true
  force_destroy     = true
}

# 복제 보고서 버킷
module "report" {
  source           = "git::https://github.com/oniops/tfmodule-aws-s3.git?ref=v1.8.0"
  context          = module.ctx.context
  bucket_name      = "exr401-report-replica-report"
  object_ownership = "ObjectWriter"
  force_destroy    = true
}

module "source" {
  source                        = "git::https://github.com/oniops/tfmodule-aws-s3.git?ref=v1.8.0"
  context                       = module.ctx.context
  bucket_name                   = "exr401-report-replica-source"
  object_ownership              = "ObjectWriter"
  bucket_key_enabled            = true
  enable_versioning             = true
  enable_replication            = true
  replication_report_bucket_arn = module.report.bucket_arn
  replication_rules = {
    "report-replica-rule" = {
      priority                  = 0
      delete_marker_replication = false

      # 중요: existing_object_replication을 false 또는 생략
      # `Batch Operations`으로 별도 처리
      existing_object_replication = false

      destination = {
        bucket = module.target.bucket_arn

        # RTC(15분 내 복제 SLA)와 복제 메트릭은 추가 요금이 발생하므로 기본값(false)을 사용합니다.
        # 복제는 RTC 없이도 비동기로 수행됩니다. SLA 가 필요하면 아래 두 값을 함께 true 로 설정하세요.
        # replication_time = true
        # metrics          = true
      }
    }
  }

  # PoC 검증 용도만 `force_destroy` 속성을 `true`로 하세요.
  force_destroy = true

  depends_on = [
    module.target,
    module.report
  ]
}
