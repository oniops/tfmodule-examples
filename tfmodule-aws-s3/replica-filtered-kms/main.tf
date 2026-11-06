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

module "target" {
  source = "git::https://github.com/oniops/tfmodule-aws-s3.git?ref=v1.8.0"
  providers = {
    aws = aws.replica
  }
  context           = module.ctx.context
  bucket_name       = "exr201-filtered-kms-target"
  object_ownership  = "ObjectWriter"
  enable_versioning = true
  force_destroy     = true
}

# 객체의 prefix 가 `sensitive/` 이고 `aws/s3`, `main-kms` 와 같은 KMS 키로 암호화된 객체만 복제 합니다.
module "source" {
  source             = "git::https://github.com/oniops/tfmodule-aws-s3.git?ref=v1.8.0"
  context            = module.ctx.context
  bucket_name        = "exr201-filtered-kms-source"
  object_ownership   = "ObjectWriter"
  bucket_key_enabled = false
  enable_versioning  = true
  enable_replication = true
  # SSE-KMS 키로 암호화된 객체를 대상으로 복제를 하는 경우 `sse_algorithm` 속성은 `aws:kms` 으로 설정
  sse_algorithm     = "aws:kms"
  kms_master_key_id = data.aws_kms_alias.origin.target_key_arn
  replication_rules = {
    "filtered-kms-replica" = {
      priority                  = 0
      delete_marker_replication = false

      destination = {
        bucket = module.target.bucket_arn
        # target 버킷에 CMK 암호화 필요시
        replica_kms_key_id = data.aws_kms_alias.replica.target_key_arn
      }

      # 복제 대상 객체를 prefix 가 `sensitive/` 인 조건으로 설정
      filter = {
        prefix = "sensitive/"
      }

      # Source 버킷의 sse_kms 키로 암호화된 객체만 복제를 함, kms_master_key_id 지정 필요
      source_selection_criteria = {
        sse_kms_encrypted_objects = true
      }
    }
  }
  force_destroy = true
  depends_on    = [module.target]
}
