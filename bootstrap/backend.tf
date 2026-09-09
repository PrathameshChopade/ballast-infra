# Bootstrap keeps its own state in the bucket it created.
#
# The chicken-and-egg problem is real but one-time: the bucket had to be built
# with local state because it did not exist. It exists now, so there is no
# reason for this module's state to live on a single laptop — the one place it
# cannot be recovered from.
#
# Losing it would not break anything immediately. It would be worse than that:
# a fresh apply would generate a new random suffix, create a second bucket, and
# leave the original — holding every other module's state — managed by nobody.
#
# The bucket is guarded by prevent_destroy, so the circular dependency here
# (state for the bucket, stored in the bucket) has no path to destroying
# itself through Terraform.
terraform {
  backend "s3" {
    bucket       = "ballast-tfstate-e5cfa9d5"
    key          = "bootstrap/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}
