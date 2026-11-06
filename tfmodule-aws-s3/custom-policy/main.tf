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

locals {
  account_id       = module.ctx.account_id
  s3_bucket_prefix = module.ctx.s3_bucket_prefix

  # Native HCL list of statement objects. Heterogeneous shapes are allowed:
  # the first statement uses Action as string and Principal as object; the second
  # uses Action as list and Resource as list.
  attach_custom_policy = [
    {
      Sid    = "AllowCloudFrontDistributeForWhiteLabel"
      Effect = "Allow"
      Principal = {
        Service = "cloudfront.amazonaws.com"
      }
      Action   = "s3:GetObject"
      Resource = "arn:aws:s3:::${local.s3_bucket_prefix}-demo-s3/*"
      Condition = {
        ArnLike = {
          "aws:SourceArn" = "arn:aws:cloudfront::${local.account_id}:distribution/*"
        }
      }
    },
    {
      Sid    = "AllowELBLogWrite"
      Effect = "Allow"
      Principal = {
        Service = [
          "logdelivery.elasticloadbalancing.amazonaws.com",
          "cloudwatch.amazonaws.com"
        ]
      }
      Action = [
        "s3:PutObject",
        "s3:PutObjectAcl"
      ]
      Resource = [
        "arn:aws:s3:::${local.s3_bucket_prefix}-demo-s3",
        "arn:aws:s3:::${local.s3_bucket_prefix}-demo-s3/*"
      ]
    }
  ]
}

module "s3Pols" {
  source                                = "git::https://github.com/oniops/tfmodule-aws-s3.git?ref=v1.8.0"
  context                               = module.ctx.context
  bucket                                = "${local.s3_bucket_prefix}-demo-s3"
  object_ownership                      = "BucketOwnerEnforced"
  attach_deny_insecure_transport_policy = true
  attach_custom_policy                  = local.attach_custom_policy
}
