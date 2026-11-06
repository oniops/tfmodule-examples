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
  bucket_name       = "exr101-basic-replica-target"
  object_ownership  = "ObjectWriter"
  enable_versioning = true
  force_destroy     = true
}

# 모든 객체를 복제 합니다.
module "source" {
  source             = "git::https://github.com/oniops/tfmodule-aws-s3.git?ref=v1.8.0"
  context            = module.ctx.context
  bucket_name        = "exr101-basic-replica-source"
  object_ownership   = "ObjectWriter"
  bucket_key_enabled = false
  enable_versioning  = true
  enable_replication = true
  replication_rules = {
    "basic-replica-rule" = {
      priority                  = 0
      delete_marker_replication = false
      destination = {
        bucket = module.target.bucket_arn
      }
    }
  }
  force_destroy = true
  depends_on    = [module.target]
}
