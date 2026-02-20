---
title: OpenWork Den - Hosted Sandboxed Workers PRD
description: End-to-end product and architecture plan for Den, covering local sandbox workers, cloud deployment, hybrid workers, rollout paths, Render feasibility tests, and release execution gates.
---

## 1) Executive summary

Den is the OpenWork hosted worker product:

- hosted sandboxed workers for teams
- accessible from OpenWork desktop, Slack, and Telegram
- ships with OpenWork skills, agents, and MCP integrations already available

This PRD maps three viable architecture paths to ship Den while staying aligned with OpenWork's core identity from `_repos/openwork/AGENTS.md`:

- OpenCode is the engine
- OpenWork is the experience layer
- local-first, cloud-ready
- composable, ejectable, and safety-first

This document proposes a staged release strategy:

1. Path A first: local sandbox workers that can be lifted to cloud as full worker instances.
2. Path B second: hybrid workers where control stays centralized but execution can be local or cloud.
3. Path C third: fully hosted Den workers for teams that want zero local operations.

Render is viable for parts of the Den stack immediately (control plane and single-tenant worker hosting), with caveats around per-worker process economics and fleet orchestration complexity.

## 2) Product framing and positioning

### 2.1 Den landing proposition (input copy)

Den positioning for launch:

- Hosted sandboxed workers for your team.
- Access workers from desktop app, Slack, or Telegram.
- Existing skills, agents, and MCP integrations are available in each hosted worker.
- Preorder pricing: `$1 first month`, then `$50/month per worker`.

### 2.2 OpenWork alignment (non-negotiable)

From `_repos/openwork/AGENTS.md` and vision docs:

- OpenWork is an open-source alternative to closed cowork products.
- Mobile and messaging access is first-class, not afterthought.
- OpenWork must remain thin over OpenCode primitives.
- Any hosted strategy must preserve ejectability and portability.

Den must not become a lock-in-only control plane. It can offer a hosted default while keeping a path back to self-host/local.

## 3) Problem statement

Today, OpenWork can run local and remote flows, but there is no complete productized Den flow for teams that need:

- predictable isolated worker runtimes per user/project/team
- centralized operations (billing, quotas, health, audit)
- integrated desktop + Slack + Telegram access without infrastructure setup
- clear migration between local experimentation and hosted production

Current gap:

- We have building blocks (`openwrk`, `openwork-server`, `owpenbot`, OpenCode proxying).
- We do not yet have a production Den control plane and worker lifecycle architecture.

## 4) Goals, non-goals, and success metrics

### 4.1 Goals

1. Ship Den as a reliable hosted worker product with isolated worker runtimes.
2. Support desktop + Slack + Telegram interaction with the same worker identity.
3. Preserve OpenWork local-first behavior with cloud deployment path.
4. Offer a hybrid mode (some workloads local, some cloud) for privacy and cost control.
5. Maintain OpenCode parity and OpenWork-server as consistent edge API.

### 4.2 Non-goals (v1-v2)

1. Full multi-cloud abstraction across all providers on day one.
2. Full enterprise governance stack (SCIM, advanced policy language) in v1.
3. General-purpose distributed compute platform beyond Den worker use cases.

### 4.3 Product success metrics

Adoption:

- `TTV (time to value)` from signup to first successful Den task < 10 minutes.
- `Activation`: >= 60% of preorders run at least one successful worker task in first 48h.

Reliability:

- Worker start success rate >= 99.0%.
- Task run success (infra-level, excluding model/tool failures) >= 98.5%.
- P95 worker reconnect time < 5s.

Safety and trust:

- Zero known secret leakage incidents from Den control plane logs.
- 100% of remote config writes gated and auditable.

Economics:

- Positive gross margin at `$50/worker` under baseline usage assumptions by v2.

## 5) User personas and jobs-to-be-done

### 5.1 Bob (IT/power operator)

Needs:

- create and share reliable team workflows
- control approvals and permissions
- deploy local-proven workflow into team-accessible hosted worker

Den JTBD:

- "I can bootstrap a worker from a known workspace, make it available to my team, and monitor it without ad-hoc server work."

### 5.2 Susan (non-technical operator)

Needs:

- execute workflows from chat or app with confidence
- no CLI, no infra, no token complexity

Den JTBD:

- "I can message a worker from Telegram/Slack and get trusted outputs with visible progress and approvals."

### 5.3 Admin/security owner

Needs:

- isolation boundaries
- auditable writes and approvals
- revocation and incident response

Den JTBD:

- "I can enforce scope and prove who changed what and when."

## 6) Core product requirements

### 6.1 Functional

1. Create worker
   - from template
   - from existing OpenWork workspace snapshot
2. Start/stop/restart worker
3. Route interactions from desktop, Slack, Telegram to worker session APIs
4. Manage worker identities and bindings
5. Configure worker skills, commands, plugins, MCP via OpenWork surfaces
6. Support local-to-cloud worker promotion
7. Support hybrid execution policy per task/run/skill class

### 6.2 Non-functional

1. Isolated runtime boundary per worker
2. Explicit data persistence model
3. Host-token approval boundary for remote config writes
4. Audit logs exportable per worker and per org
5. Graceful degradation when connectors or provider APIs fail

## 7) Den architecture paths

## 7.1 Path A - Local sandbox workers with cloud deployment (lift-and-shift)

### Concept

Each worker is modeled identically in local and cloud runtimes:

- OpenCode engine
- openwork-server edge and config control surface
- owpenbot connectors
- workspace + state volumes

Local workers run through `openwrk`; cloud workers run from the same runtime contract.

### Why this path first

- Strong OpenWork alignment (local-first, cloud-ready).
- Highest portability and ejectability.
- Lowest conceptual change for existing users.

### Lifecycle

1. User builds workflow locally in OpenWork.
2. User validates in sandbox mode.
3. User clicks "Deploy to Den".
4. OpenWork packages workspace and config references.
5. Den provisions hosted worker using same contract.
6. Worker becomes accessible via desktop/Slack/Telegram.

### Pros

- Maximum parity between local and hosted behavior.
- Easy fallback from cloud to local.
- Clear migration story for open-source users.

### Cons

- Packaging/snapshot complexity.
- Need robust handling for local-only resources (paths, local secrets, local browsers).
- Potentially slower first hosted deploy UX.

### Engineering complexity

- Medium-high

### Product risk

- Medium

## 7.2 Path B - Hybrid workers (control in cloud, execution local or cloud)

### Concept

A worker has split execution capabilities:

- cloud control plane keeps identity, policies, logs, scheduling
- execution can run locally or in cloud depending on policy and task requirements

Policy examples:

- privacy-sensitive tasks stay local
- long-running automations run cloud
- browser tasks choose provider placement (`client-machine`, `host-machine`, `in-sandbox`)

### Why this path

- Better privacy/compliance flexibility
- Cost control via execution routing
- Better user trust in early adoption

### Pros

- Strong "best of both worlds" story.
- Better handling of local authenticated contexts (browser/profile/keychain).
- Reduced cloud cost for selected workloads.

### Cons

- Scheduling and routing complexity.
- Consistency and observability become harder.
- More edge cases for failure/retry semantics.

### Engineering complexity

- High

### Product risk

- Medium-high

## 7.3 Path C - Fully hosted Den workers

### Concept

Everything executes in hosted infrastructure.

- users interact via desktop/chat
- no local runtime dependency for normal operation
- all providers and connectors hosted/managed

### Why this path

- cleanest onboarding and revenue story
- strongest enterprise admin surface potential

### Pros

- simple for non-technical teams
- consistent fleet behavior
- easier support model

### Cons

- highest infra cost and operations burden
- risk of lock-in perception if not paired with export/eject flows
- local integrations may degrade if client-side providers are required

### Engineering complexity

- Medium initially, high at scale

### Product risk

- Medium (adoption), high (unit economics) if not tightly scoped

## 7.4 Path decision matrix

Summary recommendation:

- Phase 1: Path A
- Phase 2: Path B
- Phase 3: Path C hardening and enterprise operations

Rationale:

- Path A gives fastest architecture-consistent launch.
- Path B solves critical privacy and local-context gaps.
- Path C becomes safer after policy/routing/metering are mature.

## 8) Recommended target architecture (Den v1-v3)

### 8.1 Planes

1. Control plane (Den API + worker orchestrator + billing + policy + logs index)
2. Worker plane (isolated worker runtime instances)
3. Client plane (OpenWork desktop/mobile/web + Slack/Telegram)

### 8.2 Worker runtime contract

Every Den worker exposes OpenWork-compatible edge APIs:

- `/health`
- `/status`
- `/capabilities`
- `/workspaces`
- `/workspace/:id/events`
- `/workspace/:id/engine/reload`
- `/opencode/*` proxy
- `/owpenbot/*` proxy

This keeps clients and skills reusable across local and hosted workers.

### 8.3 Identity and auth

Token classes:

- Den org token (control plane)
- worker client token (session and read actions)
- worker host token (remote write approvals/admin)

Connector credentials (Telegram/Slack) are stored in managed secret storage, injected at worker runtime.

### 8.4 Storage boundaries

Per worker:

- workspace data volume
- OpenCode/OpenWork runtime state volume
- audit/event stream durable store

Cross-worker:

- control plane metadata database
- billing and usage metrics store

### 8.5 Isolation model

Worker isolation target:

- one runtime boundary per worker
- no shared mutable filesystem between workers
- least-privilege egress and inbound controls

## 9) Local-to-cloud promotion design

### 9.1 Promotion contract

Promote a local worker to Den using explicit artifact:

- `openwork.worker.bundle.v1` (workspace snapshot + runtime metadata + config references)

Bundle includes:

- workspace files (respecting allow/deny rules)
- `.opencode` config surfaces
- worker capability descriptors
- redacted secret references (not secret values)

### 9.2 Promotion flow

1. Local preflight checks
2. Snapshot and validation
3. Upload bundle to Den control plane
4. Provision worker runtime
5. Apply secrets via org secret manager mapping
6. Run health + smoke checks
7. Publish worker access endpoints

### 9.3 Failure semantics

- all-or-nothing promotion by default
- partial promotion can be resumed from idempotent step tokens
- rollback deletes failed runtime and preserves bundle log for debugging

## 10) Hybrid workers design (Path B)

### 10.1 Execution routing policy

Policy inputs:

- task sensitivity level
- required capabilities (browser, local file access, private network)
- latency tolerance
- estimated cost budget
- operator/org policy constraints

Routing outputs:

- `execute_local`
- `execute_cloud`
- `execute_split` (rare, explicit)

### 10.2 Example routing rules

1. If task requires local browser profile and user approves local run -> local.
2. If task is long-running automation with no local dependencies -> cloud.
3. If task reads sensitive local files disallowed for cloud upload -> local.
4. If cloud quota exceeded -> fallback local with warning.

### 10.3 Consistency strategy

- shared run schema across local/cloud
- immutable run IDs and event envelope format
- deterministic checkpointing boundaries

### 10.4 Operator visibility

UI must always show:

- where execution happened
- why routing decision was made
- what capabilities were enabled/disabled

## 11) Render feasibility and micro-tests

## 11.1 Why Render is relevant for Den

Render can host:

- Den control plane services
- worker runtime services (single-tenant or pooled strategies)
- persistent volumes for worker state where required

Render strengths:

- straightforward API-driven provisioning
- managed deploy pipeline
- simple service primitives

Render limitations to account for:

- per-worker long-lived service economics
- high worker-count orchestration overhead
- need for careful volume and network design for tenant isolation

## 11.2 Micro-tests executed in this workspace

All tests performed with the configured `RENDER_API_KEY` in `.opencode/skills/render/.env`.

### Test R1 - List services with valid token

Command class:

- `GET /v1/services?limit=5`

Result:

- HTTP `200`
- 5 services returned

### Test R2 - Fetch a service by id

Command class:

- `GET /v1/services/{serviceId}`

Result:

- HTTP `200`
- service payload includes id and type (`web_service` in sample)

### Test R3 - Invalid token behavior

Command class:

- `GET /v1/services?limit=1` with invalid bearer token

Result:

- HTTP `401`
- confirms auth rejection as expected

### Test R4 - List deploys for service

Command class:

- `GET /v1/services/{serviceId}/deploys?limit=3`

Result:

- HTTP `200`
- deploy list retrieved (3 entries in sample)

### Test R5 - Render CLI availability in current environment

Command class:

- `render --version`

Result:

- CLI not installed in this workspace environment (`command not found`)
- API integration remains usable via curl + REST

## 11.3 Render outcome for Den

Conclusion:

- Render is viable for Den control plane and early worker hosting.
- For large-scale per-worker fleets, Den should keep an abstraction layer so runtime provider can evolve.

## 12) OpenWork runtime tests executed for Den path mapping

These tests validate current readiness of local and sandbox worker modes using `openwrk`.

### Test O1 - Host mode health checks

Command:

- `openwrk start --workspace <repo> --sandbox none --check --check-events --no-tui --verbose`

Observed:

- openwrk `0.11.54`
- OpenCode, openwork-server, owpenbot started
- checks passed (`Checks: ok`)

### Test O2 - Auto sandbox mode health checks

Command:

- `openwrk start --workspace <repo> --sandbox auto --check --check-events --no-tui --verbose`

Observed:

- auto selected `docker`
- sidecar target resolved to `linux-arm64`
- sandbox stack became healthy
- checks passed (`Checks: ok`)

### Test O3 - Explicit Apple container backend availability

Command:

- `openwrk start --workspace <repo> --sandbox container --check --no-tui --verbose`

Observed:

- failure with clear message: Apple container CLI not found
- confirms graceful degradation signal is present

## 13) Detailed Den system components

### 13.1 Control plane services

1. Den API gateway
2. Worker orchestrator
3. Bundle/snapshot service
4. Secret mapping service
5. Billing and metering service
6. Audit/event indexer
7. Notification and alerting service

### 13.2 Worker services

Per worker runtime:

1. openwork-server edge
2. OpenCode engine
3. owpenbot bridge
4. optional sidecars (browser provider, file provider)

### 13.3 Client integrations

1. OpenWork desktop/mobile
2. Slack bot app identity per worker/org scope
3. Telegram bot identity per worker/org scope

### 13.4 Data model (minimum)

Entities:

- `Org`
- `User`
- `Worker`
- `WorkerInstance`
- `WorkerBundle`
- `ConnectorIdentity`
- `ApprovalDecision`
- `Run`
- `AuditEvent`
- `UsageRecord`

## 14) Security and trust model

### 14.1 Security principles

1. least privilege by default
2. explicit approval for remote writes
3. portable and auditable logs
4. secrets never in git artifacts

### 14.2 Secrets model

- org-level secret vault references
- worker-level resolved env injection
- no plain secret values in worker bundle artifacts

### 14.3 Connector security

- per-worker token separation for Telegram/Slack where possible
- rotation workflow and revocation path
- health check without exposing secrets in logs

### 14.4 Audit model

At minimum record:

- who requested mutation
- what changed (resource + diff metadata)
- approval actor and decision
- timestamp and correlation id

## 15) Reliability and SRE model

### 15.1 Worker lifecycle states

- `provisioning`
- `starting`
- `healthy`
- `degraded`
- `stopped`
- `failed`

### 15.2 Health checks

1. edge check `/health`
2. status check `/status`
3. OpenCode proxy check `/opencode/health`
4. connector check `/owpenbot/health`

### 15.3 Auto-recovery

- process restart with bounded retries
- restart escalation to reprovision after threshold
- incident flag when repeated failure bursts occur

### 15.4 Observability baseline

- structured logs with worker/run correlation ids
- metrics:
  - worker start latency
  - run success/failure rates
  - approval latency
  - connector delivery rate

## 16) Cost and pricing model assumptions

### 16.1 Den price point anchor

- `$50/month per worker` after intro

### 16.2 Cost components per worker

1. compute runtime
2. persistent storage
3. network egress
4. control plane overhead allocation
5. observability and logging
6. support overhead

### 16.3 Unit economics guardrails

To sustain margin at this price, Den needs:

- auto-suspend/scale-down for idle workers
- hard limits or metering for expensive workloads
- clear quota tiers (tasks, runtime hours, storage, egress)

### 16.4 Packaging choices impacting margin

1. Dedicated always-on worker instances:
   - simplest mental model
   - potentially poor margins for low utilization
2. Warm pool + fast attach model:
   - better utilization
   - more complexity and potential cold-start edge cases

## 17) Phased implementation plan

## Phase 0 - Foundations (2-4 weeks)

Deliverables:

- finalize worker runtime contract and Den API schema
- worker bundle format v1
- basic control plane skeleton
- auth/token model with host/client boundary

Exit criteria:

- worker created and reachable with health/status endpoints

## Phase 1 - Path A launch slice (4-8 weeks)

Deliverables:

- local-to-cloud promotion flow in OpenWork app
- hosted worker provisioning in one provider environment
- desktop + Slack + Telegram read/write interactions
- approvals + audit log for remote config writes

Exit criteria:

- first cohort can deploy local workflow to hosted worker and run from chat

## Phase 2 - Hybrid execution (Path B) (4-8 weeks)

Deliverables:

- policy-based local/cloud routing
- run location transparency in UI
- local-only capability fallback paths

Exit criteria:

- hybrid policy can route at least two classes of workloads reliably

## Phase 3 - Den scale hardening (Path C maturity) (6-12 weeks)

Deliverables:

- reliability SLO automation
- tenant isolation hardening and cost controls
- advanced admin operations

Exit criteria:

- stable fleet operations and acceptable unit economics

## 18) Workstream breakdown by repository

### 18.1 `_repos/openwork` (primary product)

Likely changes:

- `packages/app`:
  - Den worker management UI
  - local-to-cloud promotion UX
  - hybrid run visibility and policy controls
- `packages/server`:
  - control-plane-safe APIs for worker operations
  - tighter approval and audit integration
- `packages/headless` (`openwrk`):
  - worker bundle build/apply commands
  - deploy adapters and preflight checks
- `packages/owpenbot`:
  - connector multi-identity hardening

### 18.2 `openwork-enterprise`

Likely changes:

- PRDs
- ops scripts
- deployment runbooks
- pricing and GTM docs alignment

### 18.3 `_repos/owpenbot`

Likely changes:

- connector auth lifecycle APIs
- health and delivery observability improvements

### 18.4 `_repos/opencode-browser` and `_repos/opencode-scheduler`

Likely changes:

- optional provider placement support for hybrid runs
- scheduled workflows in hosted worker context

## 19) Comprehensive test strategy

### 19.1 Test pyramid

1. Unit tests
2. Contract/API tests
3. Integration tests (worker lifecycle)
4. E2E tests (desktop + Slack/Telegram)
5. Chaos and resilience tests

### 19.2 Minimum test matrix

Worker lifecycle:

- create
- start
- stop
- restart
- destroy

Connectivity surfaces:

- desktop interaction
- Telegram interaction
- Slack interaction

Run modes:

- local only
- cloud only
- hybrid routed local
- hybrid routed cloud

Approval semantics:

- allow once
- deny
- timeout

### 19.3 Security test matrix

1. token misuse/revocation
2. cross-worker access attempts
3. secret leakage in logs/artifacts
4. unauthorized config mutation attempts

### 19.4 Suggested command-level E2E checks

1. `openwrk start --sandbox auto --check --check-events`
2. `curl /health`, `/status`, `/capabilities`
3. create a session and stream events via `/opencode/*`
4. test owpenbot connector health via `/owpenbot/health`
5. test approval list/reply flow

## 20) Risks and mitigations

### 20.1 Product risks

Risk: users perceive Den as closed and not portable.

Mitigation:

- explicit export/eject flows
- local-first parity documentation

Risk: hybrid mode feels confusing.

Mitigation:

- clear run location indicators
- policy explainability in UI

### 20.2 Engineering risks

Risk: per-worker infra cost explodes under idle fleets.

Mitigation:

- suspend idle workers
- warm pools
- quota policies

Risk: connector reliability degrades trust.

Mitigation:

- delivery observability
- retry and dead-letter design

### 20.3 Security risks

Risk: secret exposure in logs or snapshots.

Mitigation:

- strict redaction layer
- secret refs only in bundles
- CI checks for accidental plaintext secrets

## 21) Decision gates

### Gate A - Path A readiness

Must be true:

- local-to-cloud promotion works in >= 90% of pilot attempts
- hosted worker health checks pass under normal load
- desktop + one chat surface fully validated

### Gate B - Hybrid readiness

Must be true:

- policy routing is explainable and deterministic
- run outcome parity acceptable between local/cloud
- observability clearly attributes run location and failures

### Gate C - Scale and economics

Must be true:

- worker idle cost bounded by target margin model
- incident response playbooks validated

## 22) Launch and rollout plan

### 22.1 Cohorts

1. Internal dogfood team
2. Preorder design partners
3. Controlled public preorder activation

### 22.2 Rollout controls

- feature flags by org
- worker quota caps
- staged connector enablement

### 22.3 Launch communications requirements

Must communicate clearly:

- what is hosted now
- what remains local/hybrid
- portability and export promises
- pricing and usage assumptions

## 23) Open questions

1. Should Den v1 use dedicated per-worker services or pooled runner architecture?
2. What exact worker idle policy balances UX and margin at `$50/worker`?
3. Which MCP auth flows are supported in hosted mode at launch?
4. What migration UX should be default when local-only capabilities block promotion?
5. Should Slack and Telegram identities be per worker or per org with scoped routing?

## 24) Recommended next steps (implementation order)

1. Finalize Den API contract and worker state model.
2. Implement worker bundle format + local promotion preflight checks.
3. Build Path A MVP with one provider target and one chat connector.
4. Add hybrid policy engine as phase-2 extension, not day-one blocker.
5. Add pricing instrumentation early to prevent margin surprises.

## 25) Appendix A - Commands executed for this PRD

### Sync and status checks

- `git fetch origin --prune` and status checks run in:
  - `/Users/benjaminshafii/openwork-enterprise`
  - `/Users/benjaminshafii/openwork-enterprise/_repos/openwork`
  - `/Users/benjaminshafii/openwork-enterprise/_repos/opencode`
  - `/Users/benjaminshafii/openwork-enterprise/_repos/opencode-browser`
  - `/Users/benjaminshafii/openwork-enterprise/_repos/opencode-scheduler`
  - `/Users/benjaminshafii/openwork-enterprise/_repos/owpenbot`

### OpenWork runtime checks

- `openwrk --version`
- `openwrk --help`
- `openwrk start --workspace "/Users/benjaminshafii/openwork-enterprise" --sandbox none --check --check-events --no-tui --verbose`
- `openwrk start --workspace "/Users/benjaminshafii/openwork-enterprise" --sandbox auto --check --check-events --no-tui --verbose`
- `openwrk start --workspace "/Users/benjaminshafii/openwork-enterprise" --sandbox container --check --no-tui --verbose`

### Render API checks

- `GET /v1/services?limit=5` with valid API token (HTTP 200)
- `GET /v1/services/{serviceId}` (HTTP 200)
- `GET /v1/services?limit=1` with invalid token (HTTP 401)
- `GET /v1/services/{serviceId}/deploys?limit=3` (HTTP 200)

## 26) Appendix B - Why this PRD is consistent with OpenWork philosophy

This plan preserves:

- local-first operation
- cloud-ready deployment
- OpenCode parity through stable proxies and APIs
- composability (desktop/chat/server)
- ejectability (local and self-host paths)

This plan avoids:

- premature provider lock-in
- replacing OpenCode primitives with proprietary abstractions
- hidden state and non-auditable writes
