# ADR-0004: How Terraform state is stored and locked

- **Status:** Accepted
- **Date:** 2026-09-09
- **Stage:** 02

## Context

Every root module in Ballast needs somewhere to keep state, and that place has
to be shared, durable, and safe against two people — or a person and a CI job —
applying at the same time. Local state fails all three.

There is a bootstrapping problem: the S3 bucket that holds state must exist
before Terraform can use S3 as a backend. It cannot be created by the thing
that depends on it.

There is also a locking choice. The long-standing pattern is an S3 bucket plus
a DynamoDB table, where the table provides the atomic compare-and-set that S3
historically lacked. Since Terraform 1.10 the S3 backend can lock natively with
`use_lockfile = true`, because S3 gained conditional writes in late 2024 —
`PutObject` with an if-not-exists precondition. That removes the reason
DynamoDB was there.

## Decision

**A `bootstrap/` root module creates the state storage, applied once.** It runs
with local state initially, because the bucket does not exist yet.

**Once the bucket exists, bootstrap migrates its own state into it.** The
chicken-and-egg problem is one-time, not permanent. Leaving bootstrap on local
state forever would put the state of the module that owns the state bucket on
a single laptop — the one place it cannot be recovered from.

**Locking is `use_lockfile = true`. No DynamoDB table.** One less resource to
create, tag, pay for, and explain. The mechanism is a conditional `PutObject`,
which fails with `PreconditionFailed` when a lock is already held. Verified by
racing two applies: the first acquired, the second was refused.

**The bucket name carries a random suffix, not the account ID.** Backend
configuration must be committed for `terraform init` to work, and this
repository is public. An account ID is not a credential, but it is what an
attacker needs first to enumerate role names and attempt cross-account trust.
The `random_id` has empty `keepers` so it is generated once and never changes;
regenerating it would rename the bucket and orphan every state file in it.

**Versioning on, SSE-S3 encryption, all four public access blocks, noncurrent
versions expiring at 90 days, incomplete multipart uploads aborted at 7 days.**

**No `profile` in the provider.** A profile exists only in a local
`~/.aws/config`. CI authenticates by OIDC and receives credentials as
environment variables, so a provider pinned to a named profile cannot run
there. The default credential chain finds `AWS_PROFILE` locally and the OIDC
credentials in CI — one configuration, both environments.

## Consequences

### Better

- One resource instead of two. No table to size, tag or bill.
- The same configuration runs on a laptop and in CI without modification.
- Nothing in the public repository reveals the account ID.
- Bootstrap survives the loss of any single machine.
- State history is bounded, so the bucket does not grow without limit.

### Worse

- **`use_lockfile` is the newer path and has less production mileage.** Almost
  every existing job runs the DynamoDB pattern, so this is the less familiar
  answer in an interview and the one that has to be justified rather than
  assumed.
- **It requires Terraform 1.10 or later.** Anyone on an older version cannot
  apply against this backend at all. The `required_version` constraint makes
  that a clear error rather than a confusing one, but it is still a floor.
- **Bootstrap's state lives in the bucket bootstrap manages.** That circularity
  is deliberate and guarded by `prevent_destroy`, but it is real: destroying
  the bucket outside Terraform destroys the record of how to rebuild it.
- **`prevent_destroy` is weaker than it looks.** It refuses a plan that would
  destroy the resource. It does not stop a console deletion, and it does not
  survive `terraform state rm` followed by a destroy — as demonstrated when
  this bucket was renamed.
- **90 days is a real ceiling on recovery.** State older than that is gone.
- **SSE-S3 rather than KMS** means no per-key audit trail and no ability to
  revoke access by disabling a key.

## What would change this

- **A second engineer, or an audit requirement.** DynamoDB locking produces a
  table you can query for who holds a lock and since when. The lock file
  carries that information too, but the table is easier to inspect and is what
  a reviewer will expect.
- **Compliance requiring customer-managed keys** moves encryption to SSE-KMS,
  and with it the key policy becomes a way to lock Terraform out of its own
  state — which must then be tested.
- **A state-loss incident traced to the 90-day window** raises the window or
  adds cross-region replication of the bucket.
- **If `use_lockfile` proves unreliable under concurrent CI runs**, the
  fallback is the DynamoDB table. That is an additive change: create the
  table, add `dynamodb_table` to the backend block, re-init.
- **If Ballast ever spans multiple AWS accounts**, the state bucket moves to a
  dedicated shared-services account with cross-account roles, and this ADR is
  superseded rather than amended.
