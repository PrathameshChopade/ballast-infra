# Bootstrap: the storage that every other root module's backend depends on.
#
# This module runs with LOCAL state, because the bucket it creates is the one
# remote state lives in. It cannot store its own state in the thing it is
# creating. It is applied once and then rarely touched.

data "aws_caller_identity" "current" {}

# The bucket name is deliberately not derived from the account ID.
#
# S3 bucket names are globally unique, so the account ID is the obvious way to
# guarantee uniqueness — and it is the wrong one here. The backend
# configuration that names this bucket has to be committed for `terraform init`
# to work, and this repository is public. An account ID is not a credential,
# but it is the first thing needed to enumerate role names and attempt
# cross-account trust, which is why it does not belong in a public repo.
#
# A random suffix gives the same uniqueness and reveals nothing. `keepers` is
# empty so this value is generated once and never changes: regenerating it
# would rename the bucket and orphan every state file in it.
resource "random_id" "suffix" {
  byte_length = 4
  keepers     = {}
}

resource "aws_s3_bucket" "state" {
  bucket = "ballast-tfstate-${random_id.suffix.hex}"

  # Refuses any plan that would destroy this bucket. Note what it does not do:
  # it does not stop someone deleting the bucket in the console, and it does
  # not survive `terraform state rm` followed by a destroy. It is a guard
  # against an accidental `terraform destroy`, not a security control.
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  # Versioning is the recovery mechanism for state. A corrupted or truncated
  # state file is restored by rolling back to the previous version, and
  # without this that option does not exist.
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  # SSE-S3 (AES256) rather than SSE-KMS. State contains resource attributes
  # and can contain secrets, so it must be encrypted at rest — but the threat
  # model here is a bucket read by someone who should not have it, and the
  # bucket policy plus IAM already govern that. KMS would add per-key audit
  # trails and the ability to revoke access by disabling a key, at the cost of
  # key management, ~$1/month, per-request charges, and an extra failure mode
  # where a broken key policy locks Terraform out of its own state. Revisit if
  # a compliance requirement asks for customer-managed keys.
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    filter {}

    # 90 days of state history. This is the recovery window: past it, rolling
    # back to a state file older than 90 days is no longer possible. That is
    # an acceptable trade — a state problem is discovered within hours, not
    # months — but it is a trade, not free.
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }

  rule {
    id     = "abort-incomplete-uploads"
    status = "Enabled"

    filter {}

    # Failed multipart uploads leave parts that are billed but invisible in
    # the console. Cheap to clean up, easy to forget.
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
