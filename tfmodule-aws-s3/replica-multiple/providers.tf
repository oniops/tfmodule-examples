terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0"
    }
  }
}

# Refers to environment variables [AWS_PROFILE, AWS_REGION].
provider "aws" {
  region = module.ctx.region
}

provider "aws" {
  alias  = "replica"
  region = "ap-northeast-1"

  # Make it faster by skipping something
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_credentials_validation = true
  # skip_requesting_account_id  = true
}
