provider "aws" {
  region = var.region

  # No `profile` here on purpose.
  #
  # A profile is a local construct in ~/.aws/config; it does not exist in CI.
  # GitHub Actions authenticates by OIDC and receives credentials as
  # environment variables, so a provider pinned to a named profile would fail
  # there. Leaving it out means the provider uses the standard credential
  # chain, which finds AWS_PROFILE locally and the OIDC credentials in CI —
  # the same configuration working in both places.
  #
  # Locally:  export AWS_PROFILE=ballast   (or pass --profile to `aws`)

  default_tags {
    tags = {
      ManagedBy = "terraform"
      Project   = "ballast"
      Component = "bootstrap"
    }
  }
}
