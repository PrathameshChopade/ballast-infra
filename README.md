# ballast-infra

Terraform for the Ballast platform: AWS account scaffolding, network, EKS,
data stores and DNS. Provisions the infrastructure that `ballast-platform`
installs onto and that `nook-app` runs on.

## Layout

| Path | Purpose |
| --- | --- |
| `docs/adr/` | Architecture Decision Records |
| `PROGRESS.md` | Session log and resume point |

## Conventions

- No `[default]` AWS profile. Every command names its profile explicitly, so an
  unscoped command fails loudly instead of touching the wrong account.
- Credentials are short-lived and come from IAM Identity Center (`aws sso login
  --profile ballast`). No static access keys, locally or in CI.
- CI authenticates by OIDC federation. There are no AWS secrets in this repo or
  in GitHub Actions secrets.
- The account ID lives in variables, never hardcoded — this repository is public.
