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

data "aws_iam_policy_document" "trail" {
  statement {
    sid = "AWSCloudTrailAclCheck"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    resources = [module.trail.bucket_arn, ]
    actions   = ["s3:GetBucketAcl", ]
  }

  statement {
    sid = "AWSCloudTrailWrite"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    resources = ["${module.trail.bucket_arn}/*"]
    actions   = ["s3:PutObject"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }

  statement {
    sid    = "Deny unencrypted object uploads"
    effect = "Deny"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    resources = ["${module.trail.bucket_arn}/*", ]
    actions   = ["s3:PutObject", ]
    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["aws:kms"]
    }
  }

}


module "trail" {
  source              = "git::https://github.com/oniops/tfmodule-aws-s3.git?ref=v1.8.0"
  context             = module.ctx.context
  bucket_name         = "central-cloudtrail"
  object_ownership    = "BucketOwnerPreferred"
  object_lock_enabled = true
}

resource "aws_s3_bucket_policy" "policy" {
  bucket = module.trail.bucket_id
  policy = data.aws_iam_policy_document.trail.json
}
