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

module "basic" {
  source                  = "git::https://github.com/oniops/tfmodule-aws-s3.git?ref=v1.8.0"
  context                 = module.ctx.context
  bucket_name             = "exam-basic"
  object_ownership        = "ObjectWriter"
  enable_bucket_lifecycle = true
  lifecycle_rules = {
    "default-rule" = {
      transitions = {
        GLACIER      = 180
        DEEP_ARCHIVE = 365
      }
      expiration_days = 730
    }
  }
  attach_deny_insecure_transport_policy = true
}
