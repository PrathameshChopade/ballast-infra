# Ballast — progress log

Plan: https://claude.ai/code/artifact/bba3b040-4ce4-4963-8661-41b6e8d379fe
Resume with: `cd ~/Desktop/LearnIT && claude` then say **"resume Ballast — read PROGRESS.md"**

---

## Where I am

**Stage 00 — Ground rules (week 1)** · in progress
**Done:** tasks 1–3 (credential safety + budget). Old admin key retired, SSO working, budget alarms set.
**Next up:** tasks 4–7 — repos, pre-commit, kind cluster, ADR-0001.

---

## Working agreement

- Prathmesh writes ALL Terraform, Kubernetes YAML, Helm and pipeline config, by hand.
- Claude writes the Nook application code, explains concepts, reviews, and breaks things on purpose.
- App work is capped at weeks 2–3. Everything else is DevOps.
- Explain each concept back before moving on. Debug alone for 20 min before asking.
- Friday: one ADR / runbook / post. End of each stage: a 2-minute screen recording + a mock interview.

---

## Session log

### Session 1 — 2026-09-06
- Agreed the plan: Ballast (platform) carrying Nook (mini collaborative workspace), 15 weeks, 11 stages.
- Decided against extending money-ledger — it's deliberately static and a backend would damage it.
- Mobile deferred past week 15; keeping Flutter viable via API contract discipline (ADR-0002 in stage 01).
- **Corrected stage 00 ordering:** set up SSO and verify it BEFORE retiring the old access key,
  otherwise you lock yourself out. New path first, verify, then retire the old one.
- Found: access key `AKIA4ISKJ6PK2S2WG26V` active since Sept 2023, plaintext on Desktop, and a
  matching `[default]` profile in `~/.aws/credentials`.
- Tooling present: aws-cli 2.13 (needs upgrade), terraform 1.15.7, kubectl 1.36.2, kind, git, docker.
  Missing: helm, pre-commit.

**Stopped at:** steps 1–5 not yet run.

### Session 2 — 2026-09-06

**Sandbox decision:** the provisioned sandbox is a 180-minute resetting account. Not usable for
Ballast — Terraform state becomes fiction on reset, EKS+RDS provisioning eats 30-60 min of every
window, and nothing accumulates (no SLO history, no restore drills). Kept for console exploration
and destructive experiments only. Ballast is built in Prathmesh's own account, with `kind` locally
for ~70% of the Kubernetes hours.

**Clarified (worth re-reading if it blurs again):** kind and EKS are two *completely separate*
clusters, each with its own control plane and workers. They never connect. The only thing shared
is the manifests — one Helm chart, `values-local.yaml` vs `values-dev.yaml`. What EKS teaches that
kind cannot: IRSA, real ALB behaviour, VPC CNI / ENI-IP exhaustion, spot interruption, EBS AZ
affinity, managed services, and real cost.

**Done:**
- Old key `AKIA4ISKJ6PK2S2WG26V` deactivated (delete for real ~2026-09-13); CSV shredded.
- `~/.aws/credentials` gone; no `[default]` profile by design, so unscoped commands fail loudly.
- IAM Identity Center enabled, MFA on, `ballast` SSO profile working (AssumedRole confirmed).
- Budget alarms at $60 (50/80/100%), Cost Explorer enabled.

**Blockers found for next session:** docker socket permission denied (user not in `docker` group),
`gh` and `direnv` not installed, `git config user.name` unset.

**Open questions:**
- Region confirmed as `ap-south-1`? (Identity Center is region-locked once enabled.)
- Root account: MFA on, and zero access keys? (check via `aws iam get-credential-report`)
- Domain name for stage 03 DNS/TLS — needed by week 6, ~$12/yr.

### Session 3 — 2026-09-06

**Dropped pre-commit from stage 00.** The gitleaks hook compiles gitleaks from source; it failed
because `GO111MODULE=off` was set persistently in `~/.config/go/env` (legacy GOPATH mode). Burned an
evening on a toolchain bug protecting files that don't exist yet. Wrong order — linting belongs in
CI at stage 05, where it runs identically for everyone; pre-commit returns then as optional local
convenience.

**Replaced with:** GitHub push protection (secret scanning) at the account level — server-side,
free on public repos, can't be bypassed with `--no-verify`.

**Also fixed:** `go env -u GO111MODULE` — was breaking Go tooling machine-wide, would have bitten
again in stage 01's Go exporter.

**Rule to hold onto:** don't install tooling before there's something for it to catch.

### Session 4 — 2026-09-06

**New working agreement for docs:** Claude interviews Prathmesh, drafts the ADR, Prathmesh edits
and approves. The Friday writing hour (blog posts, postmortems) stays entirely his — that's where
the written-communication skill actually gets built.

**ADR-0001 written** (`docs/adr/0001-repository-structure.md`) — four repos, justified on change
rate and blast radius rather than team separation, which doesn't apply solo. Honest closing note
that a monorepo probably suits one developer better and four repos are partly a learning choice.

Two answers corrected during the interview, both worth remembering:
- `nook-app` gets the most *human* commits, but `ballast-deploy` gets the most commits overall
  once CI writes to it on every merge. That's the actual reason deploy is separate.
- "Nothing would change this decision" is the weakest possible reversal section. Named real
  thresholds instead — interviewers probe exactly here.

**Still open in stage 00:** docker group (needs logout), push protection, kind cluster, ADR merge.

## Session 5 — 2026-09-07

Stage 00 closed.

**Docker group fix worked, but restarting the daemon broke the kind cluster.**
The `kind` docker network was left in an inconsistent state: the daemon still
held a network record with ID `3b232c9e…`, but no matching kernel bridge
existed (`ip link show | grep br-3b232c9e` returned nothing). Containers
attached to it could not be started — `docker start` failed with
"network … does not exist" while `docker network ls` listed it.

Removing the stale network exposed the real cause. Recreating it failed with:

```
ip6tables: No chain/target/match by that name
```

Docker creates the `kind` network with IPv6 enabled and then installs
ip6tables rules into a `DOCKER` chain it creates at daemon startup. That chain
was missing, so network creation half-completed and the bridge never survived.
The kernel modules (`ip6_tables`, `ip6table_filter`) were loaded, so this was
Docker's own chain setup, not a missing module. `systemctl restart docker`
rebuilt the chains and the network created cleanly.

Correction to an earlier assumption: the cluster did not break at reboot. It
broke when the daemon restarted to pick up the new `docker` group membership.
A reboot would not have fixed it.

**Changes to `ballast-platform/kind-ballast.yaml`:**

- Added a second worker. With one worker, `kubectl drain` leaves pods Pending
  and demonstrates nothing.
- Pinned `kindest/node:v1.31.0` on every node. The config previously named no
  image, so this recreate silently pulled v1.36.1 — the cluster's Kubernetes
  version had drifted without any change to the config. Local-first only works
  if local matches what EKS will run. Revisit at stage 02 and move both
  together.
- Kept the 8080/8443 host port mappings. Ports below 1024 invite conflicts and
  buy nothing here.

**pre-commit was still installed** in `.git/hooks` despite the decision to drop
it, and blocked the first commit with "No .pre-commit-config.yaml file was
found". Removed with `pre-commit uninstall`. It returns at stage 05, once CI
exists and there is something for it to check.

**Repository initialised.** Local branch renamed `master` → `main` before the
first push, since the remote was empty and the first push fixes the default
branch name permanently. Added README (credential and account conventions) and
.gitignore (Terraform state, anything credential-shaped). ADR-0001 committed
and pushed.

**Cluster verified:** three nodes Ready on v1.31.0, 13 system pods Running.

### Stage 00 state

| Item | State |
| --- | --- |
| SSO profile `ballast`, no `[default]` | done |
| Budget alarm | done |
| Access key deactivated | done — delete on or after 2026-09-13 |
| Docker group membership | done |
| GitHub push protection | done |
| kind cluster, 3 nodes Ready | done |
| ADR-0001 pushed to `main` | done |
| `go env -u GO111MODULE` | needed before stage 01's Go exporter |
| Drain exercise | optional, not yet run |

### Still open

- Root account: MFA enabled and zero access keys? Verify with
  `aws iam generate-credential-report`.
- Domain name for stage 03 DNS/TLS (~$12/yr, needed by week 6).

### Next

Stage 01 — Nook's services get built. Mostly my hours, not yours.

## Session 6 — 2026-09-07

Stage 01 complete. Five services built, running and verified end to end.

`nook-app` now holds: `api` (Fastify + Zod-generated OpenAPI), `collab`
(Yjs + Redis backplane), `worker` (BullMQ), `exporter` (Go, distroless),
`web` (React + Vite + TipTap), a two-migration schema, and a Makefile.

### Verified, not assumed

- Two clients converge on one replica, on two replicas, and through the
  nginx WebSocket proxy.
- Both replicas killed; a reconnecting client restores the document from
  Postgres.
- Cross-workspace access refused at every route and at the WebSocket
  handshake.
- Export runs API -> BullMQ -> Go exporter -> S3 -> presigned download.
- Presigned attachment upload, confirm and download; oversize refused 413.
- `make clean && make dev`: destroyed volumes to working stack in 22s.

### Image sizes — the stage 05 table

| Image | Size |
| --- | --- |
| `exporter` (distroless static) | 7.2 MB |
| `api` (node slim) | 279 MB |
| `collab` (node slim) | 283 MB |

### Bugs found and fixed

**Initial sync was broken and the first test passed anyway.** A client
joining an existing document received nothing. In the Yjs protocol a sync
step 1 asks the *other* side for what it lacks, so the server's step 1
only moves data client-to-server; the client must send its own. The
two-client test passed because A typed after both had connected and live
broadcast covered for it. It only surfaced when a client connected to a
document written before it existed. The required sequence is now in
`protocol.ts`.

**Non-retryable job failures were retried.** A PDF export took 22 seconds
and four attempts to reach the 501 it was always going to get. Now thrown
as `UnrecoverableError`: one attempt, one second.

**Presigned URLs pointed at an unreachable host.** The endpoint the SDK
talks to and the endpoint signed into a URL for a browser are different
whenever the service sits behind an internal name. The signature covers
the host, so it cannot be rewritten afterwards.

### Environment problems fixed

- `docker compose` did not exist — apt `docker.io` ships no compose
  plugin. Symlinked the snap's standalone binary into
  `~/.docker/cli-plugins/`. It reports v5.3.1, which is not an upstream
  version number; treat its behaviour as unverified against the docs.
- `docker buildx` missing, so BuildKit refused to run. Symlinked from
  `/snap/docker/current/usr/libexec/docker/cli-plugins/docker-buildx`.
- corepack inside `node:22.11.0` carries npm's rotated registry signing
  key and dies on signature verification. The popular workaround,
  `COREPACK_INTEGRITY_KEYS=0`, disables signature verification of the
  package manager — declined. pnpm is installed via npm at a pinned
  version instead.
- Compose `web` collided with the kind cluster on host port 8080. Moved
  to 8090.
- `pkill -f 'node dist/server.js'` killed the shell running it: the
  shell's own command line contained the pattern.

### Stage 01 checkpoints

Done: data model, api, web, collab, worker, exporter, attachments and
search, probes/metrics/logs/SIGTERM on every service, multi-stage
Dockerfiles, one-command compose, ADR-0002, and the cut list held.

### Next: stage 02 — and the roles swap

From here Prathmesh writes the Terraform and I review. First task is the
state backend and its bootstrap paradox: the S3 bucket holding state must
exist before Terraform can store state in it.

Note the roadmap is half-dated on this. It says "S3 with DynamoDB
locking"; since Terraform 1.10 the S3 backend does native locking with
`use_lockfile = true` and no DynamoDB table. Terraform here is 1.15.7, so
both work. Picking one and defending it is ADR-0004.

### Still open

- Domain name (~$12/yr) — needed by week 6, blocking stage 03.
- Root account: MFA on and zero access keys? `aws iam
  generate-credential-report`.
- Delete the deactivated access key on or after 2026-09-13.
- `tflint`, `tfsec`, `infracost` not installed — stage 02 task 8 and
  stage 09, installed when there is something to point them at.
