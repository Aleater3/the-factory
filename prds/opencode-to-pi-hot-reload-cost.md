---
title: OpenCode -> Pi migration PRD (hot reload urgency, cost, and advantage)
description: Evaluate whether moving OpenWork from OpenCode to Pi is worth it, with a focus on hot reload timelines, migration cost, risk, and practical upside.
---

## Summary

OpenWork is an open-source alternative to Claude Cowork/Codex, and it is powered by OpenCode primitives (see `_repos/openwork/AGENTS.md`).

This PRD answers a direct product question:

- If hot reload in OpenCode has not shipped on the timeline we want, should we migrate from OpenCode to Pi?
- How expensive would that migration be?
- Is Pi actually easier for hot reload in practice?
- Would we get a meaningful advantage, or just swap one integration burden for another?

Bottom line from this PRD:

- A full migration to Pi is likely a medium-to-large effort (roughly 18-34 engineering weeks, depending on parity gaps).
- The near-term fastest path to user value is still to improve reload behavior in OpenWork/OpenCode integration first.
- Pi is only a clear win if it can prove session-safe hot reload and high primitive parity in a short spike.

## Why this PRD exists

Hot reload matters for OpenWork's living-system model:

- users should be able to create/edit skills, commands, and config while sessions are active
- changes should apply quickly without disruptive restarts
- reload state should be explicit, workspace-scoped, and safe

Current frustration is valid: waiting for hot reload delivery slows product velocity and user trust.

## Problem statement

We need a reliable way to apply runtime config updates quickly.

Today, OpenWork already has reload signals and a manual reload path, but this is not equivalent to true low-friction hot reload in the engine path.

Question to resolve:

- Continue investing in OpenCode-side/adapter-side reload improvements, or
- migrate engine substrate to Pi to chase faster hot reload and potentially better runtime ergonomics.

## Decision objective

Pick the option that delivers the best user-visible hot reload outcome in the next 1-2 quarters with the lowest total risk.

## Definitions and assumptions

- **OpenCode**: current engine substrate and primitive model used by OpenWork.
- **Pi**: candidate replacement engine/runtime for task execution and config lifecycle.
- **Hot reload**: config changes (skills/commands/plugins/selected engine settings) are applied without user-disruptive restart flows.

Assumptions for costing:

- team blend: 1.5-2.5 FTE engineers over migration window
- fully loaded engineer month: $20k-$28k
- security/reliability hardening included in estimates
- UI changes are moderate; most effort is runtime, compatibility, and testing

## Goals

- Estimate realistic cost and timeline for OpenCode -> Pi migration.
- Evaluate whether Pi materially improves hot reload UX and reliability.
- Define measurable go/no-go criteria.
- Provide a staged plan that avoids irreversible lock-in.

## Non-goals

- Rewriting all OpenWork UX flows.
- Shipping a zero-risk big-bang cutover.
- Assuming Pi parity without validation.

## Product principles for this decision

Grounded in `_repos/openwork/AGENTS.md`:

- Prefer predictable behavior over clever behavior.
- Keep OpenCode primitives/mental model where possible.
- Protect session continuity and workspace isolation.
- Ship user-visible value quickly, then optimize architecture.

## Options considered

### Option A: Stay on OpenCode, close hot reload gap now

Scope:

- implement robust reload queue and idle-time auto-reload behavior
- improve watcher + event consistency in host and server modes
- strengthen UI messaging and one-click recovery paths

Expected effort:

- 4-8 engineering weeks

Pros:

- fastest path to user-visible relief
- no major compatibility migration
- keeps current ecosystem and primitives intact

Cons:

- does not remove dependency on OpenCode roadmap for deeper engine-level reload semantics

### Option B: Hybrid bridge (Pi for execution path, OpenCode compatibility layer retained)

Scope:

- build adapter so OpenWork can run selected flows on Pi while preserving existing config model
- maintain partial OpenCode compatibility for skills/plugins/commands during transition

Expected effort:

- 10-18 engineering weeks

Pros:

- lower risk than full rewrite
- allows side-by-side benchmark on real user flows

Cons:

- temporary dual-stack complexity
- potential long tail of edge-case incompatibilities

### Option C: Full migration to Pi

Scope:

- switch primary engine substrate to Pi
- recreate/replace OpenCode-equivalent behavior, adapters, and operational tooling

Expected effort:

- 18-34 engineering weeks

Pros:

- potential clean slate for runtime lifecycle and hot reload

Cons:

- highest risk and longest time before users feel benefit
- parity, regression, and operational unknowns are substantial

## Cost model

### Engineering effort

| Area | Option A | Option B | Option C |
| --- | ---: | ---: | ---: |
| Discovery + architecture | 1-2 wks | 2-3 wks | 3-4 wks |
| Runtime implementation | 2-4 wks | 4-7 wks | 8-14 wks |
| Compatibility/adapters | 0.5-1 wk | 2-4 wks | 4-8 wks |
| QA + reliability + soak | 1-2 wks | 2-4 wks | 3-6 wks |
| Rollout + migration support | 0.5-1 wk | 1-2 wks | 2-4 wks |
| **Total** | **4-8 wks** | **10-18 wks** | **18-34 wks** |

### Dollar estimate (fully loaded)

Using $20k-$28k per engineer-month:

- **Option A**: ~$30k-$110k
- **Option B**: ~$75k-$250k
- **Option C**: ~$135k-$475k

Range is wide because parity gaps and reliability hardening are uncertain until a spike is complete.

### Opportunity cost

Migration-heavy paths (especially Option C) reduce capacity for:

- OpenWork UX improvements
- sharing/deployment features
- connector polish and reliability work

## Hot reload-specific analysis

Is Pi easier for hot reload?

- **Potentially yes**, but only if Pi supports all of the following natively:
  - workspace-scoped config invalidation
  - session-safe reload (no interruption of active tool calls)
  - deterministic plugin/skill lifecycle hooks
  - clear, queryable reload status/events
- **Likely not automatically** if Pi still requires process disposal/restart semantics for key config classes.

Practical conclusion:

- Pi is not automatically the "easy hot reload" answer.
- The advantage exists only if proven on real flows with measurable latency and reliability gains.

## Expected advantage if Pi succeeds

If Pi passes the criteria below, likely benefits are:

- lower time-to-apply config (target p95 <= 3s)
- less user confusion around "reload required" states
- cleaner runtime lifecycle model for future self-modifying workflows

If Pi fails criteria, net result is mostly migration overhead with limited user upside.

## Go/No-go criteria for Pi

Pi migration only proceeds beyond pilot if all are met:

- hot reload apply latency: p95 <= 3 seconds on representative workspaces
- session continuity: 99%+ reloads do not interrupt active session outcomes
- primitive parity: >= 90% of top workflows work without manual fallback
- operational stability: no critical regressions in 2-week soak
- observability: reload events and failure reasons are surfaced in API/UI

## Proposed execution plan

### Phase 0 (2 weeks): proof spike

Deliverables:

- implement one vertical slice in Pi (skills update -> reload -> next run reflects change)
- benchmark against current OpenCode path
- produce hard data: latency, failure rate, session disruption rate

### Phase 1 (2-4 weeks): user relief regardless of migration

In parallel, ship immediate improvements on current stack:

- stronger reload queue behavior
- clearer UI signals and one-click recovery
- better watcher/event parity across runtime modes

### Phase 2 decision

- If Pi spike meets go criteria: continue with Option B (hybrid bridge)
- If Pi spike misses criteria: stay with Option A and continue hardening OpenCode path

## Risks and mitigations

- **Risk**: hidden compatibility tail (skills/plugins/commands behavior mismatch)
  - **Mitigation**: force top-workflow parity matrix before expansion
- **Risk**: dual-stack complexity drags delivery
  - **Mitigation**: time-box hybrid period and maintain one default path
- **Risk**: migration consumes roadmap capacity without visible value
  - **Mitigation**: ship Phase 1 user-facing reload improvements first

## Recommendation

Recommended path:

1. Approve Phase 0 spike immediately to validate Pi on hot reload reality, not theory.
2. Ship current-stack reload UX/reliability improvements in the same window.
3. Decide with measured data, then either:
   - proceed with Option B (not full cutover), or
   - stay on OpenCode path and avoid migration cost.

This minimizes regret, gets users faster relief, and keeps strategic optionality.

## Success metrics

- user-reported reload friction reduced by >= 50%
- reload-related support/debug incidents reduced by >= 40%
- median config-to-effective-change time <= 5s (target <= 3s p95 on Pi path)
- no increase in critical runtime regressions after rollout

## Open questions

- What exact Pi primitive model maps to OpenCode skills/plugins/commands?
- What config classes in Pi can truly reload in-process vs require restart semantics?
- How much of current OpenWork server contract can remain unchanged under Pi?
- Is there a licensing/runtime cost change under expected production load?
