output "state_bucket_name" {
  description = "Name of the state bucket. Paste this into each root module's backend block."
  value       = aws_s3_bucket.state.id
}

output "region" {
  description = "Region the state bucket lives in."
  value       = var.region
}

output "backend_config" {
  description = "The backend block for other root modules, ready to copy."
  value       = <<-EOT
    terraform {
      backend "s3" {
        bucket       = "${aws_s3_bucket.state.id}"
        key          = "<component>/terraform.tfstate"
        region       = "${var.region}"
        encrypt      = true
        use_lockfile = true
      }
    }
  EOT
}
