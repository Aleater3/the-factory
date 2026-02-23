---
title: OpenWork Desktop Runtime Migration (Tauri to Electron) with Native Windows/macOS Comparison
description: Compare what it takes to migrate OpenWork desktop from Tauri to Electron, contrast against a true native macOS + Windows path, and define a practical phased delivery plan focused on Electron.
---

## Summary
OpenWork is currently a Tauri-first desktop app, but the UI and product direction are already pushing toward a broader host/client architecture where the shell should be a predictable delivery vehicle rather than a product constraint.

This PRD compares three paths:
- stay on Tauri,
- migrate desktop shell to Electron (primary recommendation),
- build native macOS + Windows apps.

Recommendation: execute an incremental Electron migration using a strangler pattern (bridge abstraction first, shell swap second, runtime cutover last), while preserving Tauri as fallback until parity gates pass.

## Context and baseline (current repo state)
From `_repos/openwork`:
- Desktop shell is in `packages/desktop` (Tauri 2.x).
- Rust desktop backend under `packages/desktop/src-tauri/src` is 44 files and about 7,373 LOC.
- There are 49 `#[tauri::command]` handlers exposed from Rust.
- Frontend Tauri bridge is `packages/app/src/app/lib/tauri.ts` at 802 LOC with 49 `invoke(...)` wrappers.
- Frontend runtime branching is significant (`isTauriRuntime()` appears 131 times).
- Release pipelines are Tauri-coupled (`tauri-action`, Tauri updater signing, macOS notarization flow, MSI/DMG bundles).
- Sidecar packaging is mature and central: `opencode`, `openwork-server`, `opencode-router`, `openwrk`, `chrome-devtools-mcp`, plus `versions.json` integrity metadata.

Interpretation:
- This is not a small shell swap.
- Most complexity is in process orchestration, filesystem operations, update flow, and release/signing.
- The UI is already web tech (Solid + Vite), so migration is feasible without rewriting product UX.

## Goals
- Replace Tauri desktop runtime with Electron while keeping product behavior and user workflows intact.
- Preserve OpenWork local-first and cloud-ready behavior from `_repos/openwork/AGENTS.md`.
- Reduce shell-level friction for development/debugging/release operations.
- Keep a clean path to web parity and future host/client architecture.

## Non-goals
- Rewriting the OpenWork UI framework.
- Rebuilding OpenCode/OpenWork core sidecars.
- Shipping full native SwiftUI + WinUI clients in this project.
- Re-architecting every backend flow at once.

## Option comparison

### Option A: Stay on Tauri
Pros:
- No migration disruption.
- Smaller binaries and lower memory overhead than Electron.
- Existing release/signing system already works.

Cons:
- Team preference mismatch (explicitly requested to move off Tauri).
- Product velocity remains constrained by Rust/Tauri bridge changes for host-specific features.
- Runtime split grows technical drag (`isTauriRuntime` branching and Tauri-only command surfaces).

Effort estimate:
- 0 to migrate.
- Ongoing opportunity cost remains.

### Option B: Migrate to Electron (recommended)
Pros:
- Strong alignment with current web-first UI and JS/TS team workflows.
- Fast iteration on desktop shell features (menus, tray, dialogs, updates, deep links).
- Mature ecosystem for packaging, crash reporting, auto-update, diagnostics.
- Simplifies onboarding for frontend-heavy contributors.

Cons:
- Higher memory footprint and larger installer artifacts.
- Security hardening must be done carefully (IPC boundary, preload, sandboxing).
- Release pipeline must be replaced/retooled.

Effort estimate:
- 8 to 12 weeks for production parity with staged rollout.
- 2 to 3 engineers (1 desktop/runtime lead, 1 product/UI integration, 1 release/infra support part-time).

### Option C: Native macOS + Native Windows apps
Pros:
- Best platform-native look/feel/perf potential.
- Strong long-term control for deep OS integrations.

Cons:
- Highest cost by far: effectively two desktop clients plus shared backend contract.
- Duplicated UI implementation (or complex webview wrappers) and doubled QA matrix.
- Slower feature velocity and larger long-term maintenance burden.

Effort estimate:
- True native UI rewrite: 6 to 12+ months.
- Native shells hosting web UI (WKWebView + WebView2): 3 to 6 months but still more overhead than Electron.

## Decision matrix (1 low, 5 high)

| Criteria | Tauri | Electron | Native macOS + Windows |
| --- | --- | --- | --- |
| Time to parity | 5 | 3 | 1 |
| Dev velocity after migration | 2 | 5 | 2 |
| Team familiarity (current stack) | 3 | 5 | 2 |
| Runtime efficiency | 5 | 3 | 4 |
| Release pipeline disruption | 5 | 2 | 1 |
| Long-term maintenance cost | 3 | 4 | 1 |
| Overall fit for near-term roadmap | 2 | 5 | 2 |

Conclusion: Electron is the best near-term tradeoff.

## Product requirements for Electron parity
Must-have parity before cutover:
- Engine lifecycle (start/stop/status/doctor/install).
- Workspace lifecycle (bootstrap/create/remote/update/export/import/forget/authorization roots).
- Openwrk and OpenWork server orchestration.
- OpenCodeRouter management and status.
- Skills/commands/config read-write flows.
- Dialog flows (pick directory/file, save file).
- Auto-update check/download/install/relaunch.
- Window behavior parity (decorations toggles, lifecycle cleanup).
- Sidecar management and integrity metadata (`versions.json`).

Nice-to-have in first Electron release:
- Better desktop diagnostics panel.
- Crash capture with user-visible recovery guidance.
- Feature flags for runtime fallback (Electron default, Tauri emergency fallback during transition).

## Recommended architecture

### 1) Desktop bridge abstraction first
Create a runtime-agnostic bridge in frontend:
- Define `DesktopBridge` contract in `packages/app`.
- Implement `TauriBridge` (existing behavior, compatibility adapter).
- Implement `ElectronBridge` (new preload IPC surface).
- Replace direct `isTauriRuntime` checks with capability checks (`runtime.type`, `runtime.capabilities`).

Why first: this removes hardcoded shell assumptions and de-risks cutover.

### 2) Electron shell package
Add `packages/desktop-electron`:
- Main process: window lifecycle, deep links, single-instance lock.
- Preload: strict IPC exposure only (no raw Node in renderer).
- Renderer: existing `packages/app` build.
- Sidecars in app resources with target-aware lookup.

### 3) IPC contract mirrors current command surface
Short-term strategy:
- Keep command names semantically aligned with current 49 Tauri commands.
- Implement handlers in TypeScript (or call service endpoints where available).
- Shift filesystem mutations to OpenWork server APIs where practical to align with architecture direction.

### 4) Sidecar supervisor in Electron main
Recreate current process lifecycle guarantees:
- Spawn and monitor `opencode`, `openwork-server`, `openwrk`, `opencode-router`, `chrome-devtools-mcp`.
- Preserve env behavior (`OPENWORK`, auth/env propagation, PATH management for sidecars).
- Ensure shutdown cleanup on app exit to avoid orphan processes.

### 5) Secure-by-default Electron posture
- `contextIsolation: true`, `sandbox: true`, `nodeIntegration: false` in renderer.
- Typed IPC allowlist only (no eval-like bridge).
- Validate all renderer-to-main payloads.
- Restrict file path operations to authorized roots where applicable.

### 6) Release and update replacement
Replace Tauri packaging lane with Electron-compatible release pipeline:
- macOS universal/dual-arch app + notarization.
- Windows installer/signing pipeline.
- GitHub release asset upload naming parity.
- Auto-update metadata and signature verification compatible with Electron updater strategy.

## Migration plan (phased)

### Phase 0 - Discovery and contract freeze (1 week)
- Freeze current Tauri command inventory into a migration sheet.
- Categorize commands: process, workspace/fs, config, updater, window, misc.
- Define Electron IPC schema and compatibility test fixtures.

Deliverables:
- `desktop-bridge-contract.md`
- command parity checklist
- cutover gate definition

### Phase 1 - Frontend bridge decoupling (2 weeks)
- Introduce runtime-agnostic bridge and capability model.
- Refactor direct Tauri imports in UI code behind bridge.
- Keep Tauri runtime fully functional.

Exit criteria:
- No business logic imports from `@tauri-apps/*` outside bridge adapter files.
- Existing desktop behavior unchanged in Tauri builds.

### Phase 2 - Electron shell bootstrap (2 weeks)
- Add Electron package with dev/build scripts.
- Load existing OpenWork UI in Electron window.
- Implement basic IPC handlers for app info, window, dialogs, and health checks.

Exit criteria:
- App boots in Electron with core navigation.
- CI produces unsigned test artifacts for macOS and Windows.

### Phase 3 - Command parity and sidecar orchestration (3 to 4 weeks)
- Implement full parity for engine/workspace/openwrk/openwork-server/opencode-router flows.
- Implement sidecar supervisor and cleanup semantics.
- Port update lifecycle (check/download/install/relaunch).

Exit criteria:
- Critical end-to-end flows pass parity test suite.
- No P0 regression versus current Tauri behavior.

### Phase 4 - Release hardening and rollout (2 to 3 weeks)
- Finalize signing, notarization, updater metadata, staged rollouts.
- Dogfood with internal users, then public canary cohort.
- Keep Tauri fallback artifact for one release cycle.

Exit criteria:
- Electron GA artifact published.
- Rollback runbook validated.

Total estimate: 8 to 12 weeks.

## QA and rollout strategy
- Run both shells in CI during migration (`desktop-tauri`, `desktop-electron`).
- Golden flow tests:
  - onboarding
  - local host mode run
  - remote workspace attach
  - skills install/update and engine reload
  - update check and install path
- Canary strategy:
  - internal team first
  - opt-in user cohort
  - default runtime flip after stability threshold

## Risks and mitigations
- Release regression risk: build/signing complexity moves from known Tauri pipeline to new Electron pipeline.
  - Mitigation: parallel release dry-runs for at least 2 cycles before default cutover.
- Security regression risk: Electron IPC misuse.
  - Mitigation: strict preload boundary, schema validation, security review checklist.
- Performance regression risk: memory increase.
  - Mitigation: explicit perf budgets and telemetry (startup time, idle RSS).
- Scope creep risk: rewriting backend logic while migrating shell.
  - Mitigation: enforce parity-first policy; no opportunistic refactors before GA.

## Success metrics
- Functional parity: 100% of P0 desktop flows pass.
- Stability: crash-free session rate matches or beats current desktop baseline.
- Performance guardrails:
  - startup to usable UI within agreed threshold,
  - idle memory increase is accepted and documented.
- Release reliability: two consecutive successful signed releases on macOS and Windows.

## Native macOS + Windows path (comparison only)

If pursued later, recommended pattern:
- Keep shared backend/service contract (OpenWork server + sidecars).
- Keep a shared web UI layer where possible.
- Build thin native shells per platform first, then selectively native-render UX areas only if justified.

What native would require beyond Electron:
- Separate shell implementations and QA for macOS and Windows.
- Separate update and installer systems.
- Separate platform-specific integration layers for permissions, file access, notifications, and process lifecycle.
- Potentially separate UI components if full native rendering is required.

Practical recommendation:
- Do not start full native rewrite now.
- Re-evaluate after Electron migration if there is a hard product requirement Electron cannot meet.

## Open questions
- Should we preserve exact command naming parity with current Tauri command IDs, or introduce versioned IPC names and a shim?
- Do we keep one-release Tauri fallback artifacts publicly, or internal-only?
- What explicit memory budget is acceptable for Electron in OpenWork context?

## Final recommendation
Proceed with Electron migration now using a parity-first strangler plan. Treat native macOS/Windows as a future optimization path, not the near-term delivery vehicle.
