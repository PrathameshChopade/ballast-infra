# ADR-0001: Four repositories, split by change rate and blast radius

**Status:** Accepted · 2026-09-06

## Context

Ballast has four distinct kinds of content: the Nook application, the AWS
infrastructure that carries it, the add-ons installed into the cluster, and the
deployment state that says which version is running where. These could live in one
repository or in several.

The usual argument for splitting repositories is organisational — separate repos let
you separate teams, ownership and access. That argument does not apply here. This is
a solo project, so there are no teams to separate and no access boundaries between
people to enforce.

The decision therefore rests on two properties that *do* apply to a solo project:
how fast each part changes, and how much damage a mistake in each can cause.

## Decision

Four repositories:

| Repo | Contains |
|---|---|
| `nook-app` | Application source for the five services, Dockerfiles, app CI |
| `ballast-infra` | Terraform: VPC, EKS, RDS, ECR, IAM, Route 53 |
| `ballast-platform` | Cluster add-ons: ArgoCD, ingress, cert-manager, observability, policy |
| `ballast-deploy` | GitOps state: image digests, environment overlays, Argo Applications |

## Rationale

### They change at very different rates

| Repo | Changes | Who commits |
|---|---|---|
| `ballast-deploy` | On every build | **CI, not me** |
| `nook-app` | Daily during weeks 2–3, then only when a platform stage requires it | Me |
| `ballast-platform` | When an add-on is introduced or upgraded | Me |
| `ballast-infra` | Rarely — a VPC is built once and seldom touched | Me |

`nook-app` collects the most *human* commits, but `ballast-deploy` collects the most
commits overall, because CI writes to it on every merge to both `nook-app` and
`ballast-platform`. Kept in one repository, those automated `bump image to sha-…`
commits would swamp the history, and finding the change that altered a subnet would
mean digging through hundreds of machine-written entries.

### They have very different blast radii

| Repo | Worst realistic outcome | Recovery |
|---|---|---|
| `ballast-infra` | `terraform apply` destroys an RDS instance or a subnet | Hours to days; **data may be gone permanently** |
| `ballast-platform` | cert-manager stops renewing TLS, or Prometheus dies and monitoring goes blind | Hours, and possibly unnoticed at first |
| `ballast-deploy` | The wrong image is deployed | Minutes — revert the commit, ArgoCD reconciles |
| `nook-app` | A bug ships | Minutes — canary analysis fails and rolls back automatically |

These are not comparable risks, and they should not share review rules. A change that
can permanently delete a database deserves stricter gates than one that changes a
version string. Separate repositories make that difference enforceable rather than
aspirational.

### The app/deploy split is a real security boundary

CI needs write access to `ballast-deploy` in order to open deployment PRs. It does
not need write access to application source or to Terraform. Splitting them means a
compromised CI token can propose a deployment but cannot alter infrastructure or
inject code.

## Consequences

**Better**

- Infrastructure history stays readable, uncontaminated by machine-generated commits.
- Review rigour and CI gates can be set per risk level rather than uniformly.
- The CI token's write access is narrowed to exactly one repository.
- Matches the standard GitOps layout, so the structure is familiar to reviewers and
  transfers directly to how most teams organise this.

**Worse**

- Cross-cutting changes need coordinated PRs in a specific order. Adding a config
  value touches Terraform (the secret), `nook-app` (reading it) and `ballast-deploy`
  (the overlay) — three PRs where a monorepo would need one.
- No atomic change is possible across repositories, so there is always a window where
  they disagree with each other.
- Four sets of workflows, secrets and branch protection rules to maintain, for one person.

## What would change this

- **If coordinated multi-repo PRs exceed roughly a third of all changes.** At that
  point the coordination tax is larger than the isolation benefit, and a monorepo with
  path-filtered CI and CODEOWNERS would give most of the same separation for less work.
- **If maintaining four CI configurations starts consuming time that belongs to the
  platform work.** The repositories exist to serve the project, not the reverse.
- **If `ballast-platform` and `ballast-deploy` turn out to change together most of the
  time.** They are split on the theory that add-ons and deployment state move
  independently; if practice disagrees, merging them costs little.

A monorepo is arguably the better fit for a single developer. Four repositories are
chosen deliberately here partly to practise the multi-repo GitOps pattern that most
employers actually run — a learning objective, and one worth naming honestly rather
than dressing up as pure engineering necessity.
