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
