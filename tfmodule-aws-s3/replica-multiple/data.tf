data "aws_kms_alias" "origin" {
  name = "alias/aws/s3"
}

data "aws_kms_alias" "replica" {
  provider = aws.replica
  name     = "alias/aws/s3"
}
