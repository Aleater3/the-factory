---
title: Workspace sharing (phased)
description: Phase 0 shares credentials + config; later phases add path-based per-workspace endpoints and warm multi-connection switching.
---

## Summary
OpenWork is a mobile-first, premium UX layer on top of OpenCode (see `_repos/openwork/AGENTS.md`).

We need a `Share...` action in the `...` menu next to a workspace (in the sidebar) that makes sharing discoverable and practical.
"Sharing" in OpenWork should support multiple surfaces:
- Access to a running workspace (credentials)
- Reuse of workflows/config (exportable bundle)
- Messaging surfaces (Slack/Telegram/WhatsApp via owpenbot, alpha)

We will ship this in phases. Phase 0 is intentionally small: show credentials + a short explanation, plus the existing config bundle export. The later phases do the real architectural shift: a single host should expose multiple workspaces as independent endpoints (path-based), and the client should keep multiple connections warm so switching feels instant.

## Goals
- Phase 0: Workspace-level share UI that exposes credentials and explains what they do.
- Make config/workflow sharing a first-class option (export/import `.openwork-workspace`).
- Phase 1: Path-based per-workspace endpoints so "Share workspace" truly shares that workspace, not "whatever is active".
- Phase 2: Keep multiple workspace connections warm (remote or local) so switching is seamless.
- Long term: OpenWork can run as a stand-alone system (clients connect to OpenWork servers; the server proxies OpenCode).

## Non-goals
- Building a user/role system (viewer/admin) or an invite/membership product.
- Real-time collaborative editing.
- Solving NAT traversal (LAN/VPN/tunnel guidance is enough).

## Phased plan

### Phase 0 (MVP): Credentials + explanation + config bundle
User experience focus:
- Make sharing discoverable: `Share...` next to workspace.
- Keep it simple: copy URL + token, with clear safety copy.
- Reuse existing "workspace package" export for sharing skills/plugins/commands.
- Bots section is present but explicitly "alpha"; do not add QR pairing UX here.

Technical focus:
- No new backend API is required.
- Use existing token sources:
  - local host: `openwork_server_info` (clientToken/hostToken + connectUrl)
  - remote OpenWork workspace: use the workspace's OpenWork host URL and the token used to connect (today this is stored globally; see Phase 0.5)
- Make sharing not-fragile:
  - today, host tokens rotate whenever the OpenWork server restarts
  - in direct runtime, local workspace switching restarts the engine (and stops the OpenWork server), which invalidates previously shared credentials
  - Phase 0 should either (a) persist host tokens across restarts or (b) clearly warn that switching workspaces can invalidate a share

### Phase 0.5: Enclose global settings into per-workspace credentials
Problem:
- Remote OpenWork connection details are currently "global settings" (URL + token in localStorage), not attached to a specific workspace.
- This makes multiple remote workspaces fight over a single token and makes the share UX confusing.

Goal:
- A remote workspace record should carry its own `openworkHostUrl` + `openworkAccessToken` (stored safely) so:
  - you can have multiple remote workspaces connected at once
  - switching doesn't require rewriting global settings
  - `Share...` can show the exact credentials for that workspace

### Phase 1: Path-based per-workspace endpoints (single port)
Decision (from feedback): we want a path-based gateway.

Goal:
- A single OpenWork host port (e.g. `http://host:8787`) exposes multiple workspace endpoints:
  - `http://host:8787/w/<workspaceId>` is a "workspace server" base URL
  - the OpenCode proxy becomes `http://host:8787/w/<workspaceId>/opencode/...`
- Sharing a workspace becomes copying credentials for `w/<workspaceId>`, not the global host.

This removes the global "active workspace" coupling and enables multiple clients to access different workspaces at the same time without stepping on each other.

### Phase 2: Warm multi-connection switching (keep connections active)
Goal:
- Switching between workspaces should feel instant.
- The first connection can be slow; subsequent switches should reuse a warm connection.

Implementation direction:
- Treat engine runtime as a first-class lever:
  - local switching can be materially faster when `Engine runtime = Openwrk orchestrator` (no engine restart per workspace)
  - remote switching still needs client-side caching
- Keep a small per-workspace connection pool in the client for remote workspaces:
  - cached OpenWork client (for host config + bots)
  - cached OpenCode client (via OpenWork proxy) + basic health/session cache
- Background refresh for inactive workspaces (health + sessions list) with backoff.

## Current state (mapped to real code)
This PRD is grounded in OpenWork `origin/dev` (as of 30fa071).

### The sidebar already has multi-workspace UI
- Workspace list + actions live in `packages/app/src/app/components/session/sidebar.tsx`.
  - Current actions: `Edit connection`, `Test connection`, `Remove`.
  - This is the correct surface for `Share...`.

### Remote workspace connection UI exists
- Remote connect modal: `packages/app/src/app/components/create-remote-workspace-modal.tsx`.
  - Collects OpenWork host URL + token, plus optional directory/displayName.

### Host credentials already exist (but buried in Settings)
- Settings has a "OpenWork server sharing" panel:
  - URL + access token (client token) + server token (host token)
  - `packages/app/src/app/pages/settings.tsx` (remote tab)
- Token source is a tauri command:
  - `packages/app/src/app/lib/tauri.ts` -> `openworkServerInfo()`
  - `packages/desktop/src-tauri/src/commands/openwork_server.rs` -> `openwork_server_info`
- The desktop spawns the OpenWork server and generates tokens:
  - `packages/desktop/src-tauri/src/openwork_server/mod.rs` generates `client_token` and `host_token`
  - `packages/desktop/src-tauri/src/openwork_server/spawn.rs` passes flags:
    - `--token <client_token>` and `--host-token <host_token>`
    - `--cors *`
    - `--approval auto` (important: safe only when not externally shared)

### Engine mode selection exists (source + runtime)
OpenWork already exposes exactly the engine knobs you asked about:
- Engine source (where the OpenCode binary comes from): Bundled sidecar vs System install (PATH)
  - UI: `packages/app/src/app/pages/settings.tsx` (Engine section)
  - Persistence: `packages/app/src/app/app.tsx` stores `openwork.engineSource` in localStorage
- Engine runtime (how local OpenCode is orchestrated): Direct vs Openwrk daemon
  - UI: `packages/app/src/app/pages/settings.tsx` (Engine section)
  - Persistence: `packages/app/src/app/app.tsx` stores `openwork.engineRuntime` in localStorage
  - Workspace switching behavior: `packages/app/src/app/context/workspace.ts`
    - direct: stop/start engine on workspace changes
    - openwrk: call `openwrkWorkspaceActivate()` + reconnect

Sensitivity summary:
- Workspace sharing is primarily about the OpenWork server (`openwork-server` sidecar). That server is started regardless of engine runtime.
- `Engine runtime = openwrk` mainly changes how fast local workspace switching can be and where we can implement "keep connections warm".
- Important: `Engine runtime = direct` currently makes sharing brittle during local workspace switching.
  - `packages/app/src/app/context/workspace.ts` uses `engineStop()` + `engineStart()` for direct runtime workspace switches.
  - `packages/desktop/src-tauri/src/commands/engine.rs` `engine_stop` stops the OpenWork server manager.
  - `packages/desktop/src-tauri/src/openwork_server/mod.rs` generates fresh UUID tokens on each OpenWork server start.
  - Result: previously shared `Access token` can become invalid after a workspace switch (or engine restart).

### Openwrk daemon is a real component when runtime = openwrk
- Desktop spawns openwrk daemon (sidecar `openwrk`) and uses its HTTP API:
  - spawn + state reading: `packages/desktop/src-tauri/src/openwrk/mod.rs`
  - tauri commands: `packages/desktop/src-tauri/src/commands/openwrk.rs` (`openwrk_status`, `openwrk_workspace_activate`, `openwrk_instance_dispose`)
- openwrk daemon routes (today): `/health`, `/workspaces`, `/workspaces/:id/activate`, `/instances/:id/dispose`
  - implementation: `packages/headless/src/cli.ts` (daemon router)

Important detail:
- openwrk workspace ids are `ws-<sha1prefix>` (see `packages/headless/src/cli.ts` `workspaceIdForLocal()`)
- openwork-server workspace ids are `ws_<sha256prefix>` (see `packages/server/src/workspaces.ts` `workspaceIdForPath()`)
These ids are different; the PRD treats openwrk ids as internal orchestration identifiers and uses openwork-server ids for shareable workspace endpoints.

### openwrk (headless) already runs openwork-server in single-workspace mode
This matters for the "stand-alone system" goal.

- `openwrk start/serve` can spawn:
  - opencode
  - openwork-server
  - owpenbot
  - all under a CLI-managed run id
- openwork-server is launched with exactly one `--workspace` today:
  - `packages/headless/src/cli.ts` -> `startOpenworkServer()` builds args with a single `--workspace <path>`

Implication:
- openwrk already models "workspace == server" for headless operation.
- Multi-workspace on a single shared port is not implemented there yet; that's what Phase 1 path mounts (or a gateway) would enable.

### Workflow/config sharing already exists as an export/import bundle
This is the "share skills/plugins/commands" path.

- Export produces a `.openwork-workspace` zip that includes `opencode.json` + `.opencode/**` and a `manifest.json`.
  - `packages/desktop/src-tauri/src/commands/workspace.rs` -> `workspace_export_config`
- Import extracts `opencode.json` and `.opencode/**` only and skips secret-like filenames.
  - `packages/desktop/src-tauri/src/commands/workspace.rs` -> `workspace_import_config`

### Bots exist (owpenbot)
- Adapters:
  - Telegram: `packages/owpenbot/src/telegram.ts`
  - Slack: `packages/owpenbot/src/slack.ts`
  - WhatsApp: `packages/owpenbot/src/whatsapp.ts`
- The OpenWork server already exposes token wiring endpoints:
  - `POST /workspace/:id/owpenbot/telegram-token`
  - `POST /workspace/:id/owpenbot/slack-tokens`
  - `packages/server/src/server.ts`

### The OpenWork server is currently "active-workspace" based for clients
This is the core coupling that makes true per-workspace sharing impossible today.

- `/opencode` proxy always targets `config.workspaces[0]`:
  - `packages/server/src/server.ts` -> `proxyOpencodeRequest()` uses `config.workspaces[0]`
- `GET /workspaces` returns only the active workspace:
  - `packages/server/src/server.ts` route `GET /workspaces` returns `[active]`

### Workspace IDs already exist and are stable
- OpenWork server workspace IDs are derived from the workspace path:
  - `packages/server/src/workspaces.ts` -> `workspaceIdForPath(path)` returns `ws_<sha256prefix>`
- This is good for sharing: the shared URL can include the workspace ID (`/w/ws_abc123...`) without inventing a new identifier.

### Remote OpenWork credentials are currently global (not enclosed)
- Global localStorage settings:
  - `openwork.server.urlOverride`
  - `openwork.server.token`
  - `packages/app/src/app/lib/openwork-server.ts`
- Remote workspace records do not store tokens:
  - `packages/desktop/src-tauri/src/commands/workspace.rs` `workspace_create_remote` stores `openwork_host_url` but not token
  - `packages/app/src/app/context/workspace.ts` updates global OpenWork settings on connect

This is why Phase 0.5 is necessary.

## Phase 0 UX: Share modal

### Entry point
- Add `Share...` to the workspace row menu in `packages/app/src/app/components/session/sidebar.tsx`.

### Modal contents (Phase 0)
Section 1: "Access"
- Show:
  - `OpenWork server URL`
  - `Access token`
- Provide `Copy` buttons.
- Explanation text (short, not developer-y):
  - "Share with trusted people only. Anyone with this can connect to your workspace." 
  - "Best on the same Wi-Fi. For remote access, use a VPN/tunnel."
  - "If you use Engine runtime = Direct, switching local workspaces can restart the host and invalidate this token. Openwrk runtime keeps shares more stable."

Section 2: "Config bundle"
- For local workspaces:
  - `Export config` (uses existing export)
  - microcopy: "Exports `.opencode/` + `opencode.json` (skills, commands, plugins, MCP). Secrets are excluded."
- For remote workspaces:
  - show disabled state: "Export is only supported for local workspaces."

Section 3: "Bots" (alpha)
- Label clearly as alpha.
- No QR/pairing UX inside this modal.
- Provide a single CTA: "Open bot settings" (deep link to existing Settings section).

## Share payload / deep link (Phase 1 target)
Decision (from feedback): deep links should be configured per workspace.

We need a canonical share payload format that is:
- versioned
- copy/paste friendly
- safe-ish (avoid leaking secrets in server logs)

Proposed format:

1) A plain-text "connection block" for humans:
```
OpenWork Workspace
name: Finance Ops
url:  http://host:8787/w/ws_abc123def456
token: <access token>
```

2) A deep link for OpenWork clients:
- `openwork://join#<base64url(json)>`

JSON payload:
```
{
  "v": 1,
  "kind": "openwork.workspace",
  "label": "Finance Ops",
  "workspace": {
    "id": "ws_abc123def456",
    "baseUrl": "http://host:8787/w/ws_abc123def456"
  },
  "auth": {
    "token": "..."
  }
}
```

Notes:
- The `ws_...` shape matches OpenWork server's current `workspaceIdForPath()` output.
- The important part is `workspace.baseUrl` (already fully scoped).
- The token is a bearer secret; UI should encourage trusted-only sharing.
- Phase 0 can ship without deep links. Phase 1 introduces them.

## Phase 1 architecture: path-based per-workspace endpoints

### Desired invariant
"Workspace" is a stable endpoint:
- The thing you share should keep pointing to the same workspace.
- Two clients can connect to two different workspaces on the same host without collisions.

### Proposed routing
Introduce a path mount for each workspace:
- Base URL: `http://host:8787`
- Workspace mount: `/w/<workspaceId>`

### Where the path-based routing lives
Recommended: implement mounts inside openwork-server.

Why:
- openwork-server is the thing clients already connect to and share.
- It already knows the workspace list (`--workspace` repeatable in `packages/server/src/config.ts`).
- It already proxies to OpenCode and can set workspace-specific directory headers.

Alternative (later): openwrk daemon as a gateway.
- openwrk already has a daemon and a workspace registry.
- openwrk already runs openwork-server in single-workspace mode.
- It could evolve into a reverse proxy where `/w/<id>` routes to a per-workspace openwork-server instance.
- This is a larger operational change; keep as a follow-on if we need process isolation.

Within the workspace mount, expose a workspace-scoped API surface:
- `GET /w/<id>/health`
- `GET /w/<id>/status`
- `GET /w/<id>/capabilities`
- `GET /w/<id>/opencode/...` (proxy to OpenCode for that workspace)
- Workspace config surfaces can either be:
  - mounted versions (`GET /w/<id>/skills`, `POST /w/<id>/skills`, etc), or
  - existing explicit routes (`/workspace/:id/...`) used by clients that already track IDs

Recommendation: implement mounted routes for the "client" path first (opencode proxy + basic status), and keep existing `/workspace/:id/...` for admin/config tooling until migrated.

### Server config changes (packages/server)
Today:
- client auth is `config.token`
- host auth is `config.hostToken`
- active workspace is `config.workspaces[0]`

Phase 1 target:
- Phase 1A (recommended first cut): keep the existing global bearer token and add path-based routing.
  - This makes the URL workspace-specific even if the token is still host-wide.
  - This is consistent with Phase 0's "trusted people" stance.
- Phase 1B (hardening): per-workspace tokens + "share enabled" toggles.
  - This turns path mounts into true independent capability boundaries.
- workspace selection is derived from the mount path, not from `workspaces[0]`

Concrete code that must change:
- `packages/server/src/server.ts`
  - Phase 1A: route matching must resolve a workspace from `/w/<id>` and pass it to proxy + handlers.
  - Phase 1B: `requireClient()` currently checks `token === config.token`; must accept a workspace token map.
  - `proxyOpencodeRequest()` currently uses `config.workspaces[0]`; must resolve workspace by id.
  - `GET /workspaces` currently returns only active; likely becomes host-only or returns all (non-breaking decision needed).
- `packages/server/src/types.ts`
  - `ServerConfig` must represent per-workspace access tokens (and optionally per-workspace host tokens).
- `packages/server/src/config.ts`
  - parsing must support reading per-workspace tokens from file config (recommended) and/or env.
  - CLI flags today (`--token`, `--host-token`) are global; Phase 1 needs a way to configure per-workspace tokens.

### Desktop spawning changes (packages/desktop)
Today, the desktop spawns exactly one OpenWork server with one token pair.

Phase 1 target:
- Either:
  - generate and persist per-workspace access tokens, and pass them into the server at startup, or
  - mint tokens lazily when the user shares a workspace, and hot-reload server auth state.

Likely touch points:
- `packages/desktop/src-tauri/src/openwork_server/mod.rs` (token generation and snapshot model)
- `packages/desktop/src-tauri/src/openwork_server/spawn.rs` (flag/env surface)

### Security/approval behavior
Important: today desktop spawn forces `--approval auto`.

Once a workspace is shared externally, approval must become manual.
Phase 1 should introduce:
- a "share enabled" toggle per workspace endpoint
- when enabled:
  - `approval` defaults to manual
  - the UI surfaces approvals clearly (host device remains the approver)

## Phase 0.5 data model: per-workspace credentials (enclosure)

### What to change
Remote OpenWork credentials must move from global settings to the workspace record.

Code today:
- global settings: `packages/app/src/app/lib/openwork-server.ts` writes `openwork.server.token`
- workspace records: `WorkspaceInfo` has `openworkHostUrl` and `openworkWorkspaceId`, but no token
  - `packages/app/src/app/lib/tauri.ts` type `WorkspaceInfo`
  - `packages/desktop/src-tauri/src/commands/workspace.rs` struct persistence

Phase 0.5 target:
- Extend `WorkspaceInfo` to include an access token reference:
  - preferred: store token in OS keychain and persist a keychain reference
  - acceptable stopgap: encrypt-at-rest in app data dir (not in repo)

Concrete code changes:
- `packages/desktop/src-tauri/src/types.rs` `WorkspaceInfo` add `openwork_token_ref` (or similar)
- `packages/desktop/src-tauri/src/commands/workspace.rs`
  - `workspace_create_remote` store token ref
  - `workspace_update_remote` update token ref
- `packages/app/src/app/context/workspace.ts`
  - stop writing global `openworkServerSettings` during remote workspace activation
  - use the workspace's stored token when calling `resolveOpenworkHost()` and building OpenWork server clients
- `packages/app/src/app/pages/settings.tsx`
  - demote global OpenWork URL/token inputs to an advanced/defaults area (optional)
  - primary editing happens via `Edit connection` per workspace

## Phase 2: keep connections warm

### Problem in current UI
- The app maintains a single active OpenCode client (`client()` in `packages/app/src/app/app.tsx`).
- Sidebar session grouping uses `client.session.list()` from the active connection only.
- For multiple remote workspaces, the app cannot show live session lists or connection state without switching.

### Proposed client-side approach
Add a small connection pool keyed by workspaceId:
- `opencodeClientByWorkspaceId: Map<string, Client>`
- `sessionListByWorkspaceId: Map<string, Session[]>`
- `healthByWorkspaceId: Map<string, { ok: boolean; checkedAt: number }>`

Integration points:
- `packages/app/src/app/context/workspace.ts`
  - new helper: `getOrCreateClient(workspaceId)`
  - background refresher: `warmWorkspace(workspaceId)`
- `packages/app/src/app/app.tsx`
  - replace single `sidebarSessions()` with per-workspace session caches when remote
  - switching uses an existing warm client when available

Constraint:
- We should not keep infinite SSE subscriptions; start with:
  - periodic health checks
  - periodic `session.list()` for inactive workspaces (with backoff)
  - SSE only for the active workspace

## Implementation map (what will actually change)

### Phase 0
- `packages/app/src/app/components/session/sidebar.tsx`
  - add `Share...` action in the workspace menu
- `packages/app/src/app/components/share-workspace-modal.tsx` (new)
  - render credentials + config export CTA + bots alpha CTA
- `packages/app/src/app/context/workspace.ts`
  - wire modal open/close and actions to existing token sources
- `packages/desktop/src-tauri/src/openwork_server/mod.rs`
  - persist/reuse the host `client_token` + `host_token` so shared credentials survive engine restarts
  - (optional) add an explicit "Rotate tokens" action instead of implicit rotation

### Phase 0.5
- `packages/app/src/app/lib/openwork-server.ts`
  - deprecate global token storage as the primary source
- `packages/app/src/app/context/workspace.ts`
  - connect using per-workspace token
- `packages/desktop/src-tauri/src/types.rs`
  - add token reference fields to `WorkspaceInfo`
- `packages/desktop/src-tauri/src/commands/workspace.rs`
  - persist token refs on create/update

### Phase 1A (path mounts, global token)
- `packages/server/src/server.ts`
  - introduce `/w/<id>` mount routing
  - scope `/opencode` proxy by workspace id (instead of `config.workspaces[0]`)
  - scope `/status` and `/capabilities` within the mount
- `packages/app/src/app/lib/openwork-server.ts`
  - add helpers to build a mounted baseUrl (`${host}/w/${workspaceId}`)
- `packages/app/src/app/components/share-workspace-modal.tsx`
  - share the mounted URL for the selected workspace

### Phase 1B (per-workspace tokens + share enabled)
- `packages/server/src/types.ts`
  - represent per-workspace access tokens
- `packages/server/src/config.ts`
  - support configuring per-workspace tokens from file config
- `packages/server/src/server.ts`
  - validate bearer token per workspace
- `packages/desktop/src-tauri/src/openwork_server/*`
  - pass per-workspace tokens/config to the OpenWork server (or mint them on demand)

### Phase 2
- `packages/app/src/app/context/workspace.ts`
  - add connection pool + warmers
- `packages/app/src/app/app.tsx`
  - sidebar session grouping uses per-workspace caches for remote

Note:
- For local workspaces, Phase 2 should strongly prefer `Engine runtime = openwrk` to avoid tearing down the host stack during workspace switches.

## Migration notes
- Existing users with remote OpenWork workspaces rely on global token settings.
- Phase 0.5 must:
  - read the legacy global token
  - prompt to attach it to a specific workspace (or do it automatically for the active remote workspace)
  - stop mutating it when switching between remote workspaces

## Testing plan

### Phase 0
- Local host: open Share modal for a local workspace; verify URL + token match Settings.
- Remote workspace: open Share modal; verify it shows correct host URL and token.
- Export bundle: export from local workspace and inspect archive contains `.opencode/**` and `opencode.json`.
- Token stability: copy Access token, restart the engine (or switch local workspace), confirm the token remains valid (or the UI warns explicitly if we choose not to stabilize it).

### Phase 1
- Host runs multiple local workspaces.
- Share two different workspace endpoints (`/w/ws_...` and `/w/ws_...`) to two clients.
- Verify clients do not affect each other and both can run prompts.

### Phase 2
- Connect to two remote workspaces.
- Verify switching is fast after first connect.
- Verify sidebar shows last known health + sessions for both without switching (as available).
- Local: with `Engine runtime = openwrk`, switch between two local workspaces and confirm the host stack stays up (no token rotation, no reconnect storms).

## Open questions (remaining)
- Token storage:
  - Where do we store per-workspace tokens safely (keychain vs encrypted file) in desktop/mobile?
  - Where do we store host openwork-server tokens so they survive engine restarts (and how do we rotate them)?
- Engine/runtime defaults:
  - Should enabling sharing recommend (or automatically switch to) `Engine runtime = openwrk` to avoid restarts during workspace switching?
- Workspace discovery:
  - Do we keep `GET /workspaces` client-visible once path mounts exist, or make it host-only?
  - Do we need a host-only "list all workspaces" endpoint so the UI can share non-active workspaces without pre-activating them?
- ID alignment:
  - If we ever use openwrk as a path-based gateway, do we unify openwrk workspace IDs (`ws-...`) and openwork-server IDs (`ws_...`) or keep an explicit mapping layer?
- Bots:
  - How do we ensure inbound Slack/Telegram messages are routed to the intended workspace when the host has many (alpha)?

## References
- `prds/remote-first-openwork.md`
- `prds/workspace-sidebar-hub.md`
- `prds/openwork-remote-workspace-clarity.md`
