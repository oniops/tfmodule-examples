output "source_bucket" {
  value = module.source.bucket_name
}

output "target_bucket" {
  value = module.target.bucket_name
}

output "report_bucket" {
  value = module.report.bucket_name
}

output "replication_role_arn" {
  value = module.source.replication_role_arn
}
