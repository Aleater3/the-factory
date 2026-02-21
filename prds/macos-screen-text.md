---
title: ScreenText for macOS (Apple Silicon) - text-only screen memory
description: Build a Swift-only, macOS-native, Apple Silicon-only, text-only screen memory tool that captures on-screen text via Accessibility or OCR, stores locally with near-zero footprint, CLI-first with a small app later.
---

## Summary
ScreenText is a macOS-only (Apple Silicon) utility, implemented in Swift, that stores a searchable text history of what was visible on screen. It captures text via Accessibility APIs first, falls back to OCR (Vision) when needed, and stores only text plus minimal metadata locally. The first version ships as a CLI daemon with a tiny control surface; a small Swift menu bar app follows. No audio, no video, no cloud sync, no telemetry by default. The entire product optimizes for near-zero footprint and predictable, local-only behavior.

## Reference analysis: screenpipe (repo review)
Screenpipe provides a broad, local-first “AI memory” system. Key observations from the repo and docs:
- Captures screen and audio; stores locally in SQLite with FTS5; provides a local API and Tauri UI.
- Uses Apple Vision OCR on macOS; also uses accessibility text in separate pipelines.
- Uses continuous capture with video chunks and FFmpeg for timeline; new specs propose event-driven capture with accessibility-first + OCR fallback and snapshot storage.
- Emphasizes privacy (local-only by default) and supports multi-monitor capture.

ScreenText intentionally narrows scope: text-only capture, no audio, no video timeline, no plugin system, and no cloud sync. We borrow the event-driven, accessibility-first approach to minimize CPU, disk, and latency.

## Product principles (explicit)
- Zero-footprint first: avoid polling, avoid heavy encoders, avoid storing images; favor event-driven capture and text-only storage.
- Local-only by default: no network calls, no accounts, no telemetry, no cloud dependencies.
- Native macOS libraries: use ScreenCaptureKit, Accessibility APIs, Vision, and system SQLite; keep third-party dependencies minimal.
- Swift-only implementation: daemon, CLI, and app targets are all Swift and use Apple frameworks.
- Predictable behavior: users can see exactly when/why captures happen and can pause/stop instantly.
- Apple Silicon only: optimize for Neural Engine and modern frameworks; do not support Intel.

## Implementation stack (Swift-only, native)
- Language/toolchain: Swift 6, Swift Package Manager, Xcode.
- UI (future small app): SwiftUI with AppKit bridge for menu bar behavior.
- Capture/event APIs: Accessibility (AXUIElement/AXObserver), NSWorkspace, CGEventTap, NSPasteboard.
- OCR/capture fallback: Vision (`VNRecognizeTextRequest`) + ScreenCaptureKit.
- Storage: `SQLite3` (system library) + FTS5.
- Logging/ops: OSLog + launchd LaunchAgent.

## Goals
- Capture on-screen text reliably using Accessibility first, OCR fallback second.
- Provide fast, local full-text search with minimal metadata filters.
- Run with near-zero idle CPU and small memory footprint.
- Provide a CLI-first workflow for install, start/stop, status, and search.
- Keep installation and uninstallation straightforward and fully local.

## Non-goals (v1)
- No audio capture or transcription.
- No video or image storage.
- No cloud sync, accounts, or remote API.
- No complex UI or timeline playback.
- No plugin system or automation rules.
- No Intel macOS support.

## Target users
- Knowledge workers who want to recall text seen earlier (docs, chats, browsers).
- Developers who want a lightweight, local, searchable record of code or logs they saw.
- Privacy-sensitive users who avoid cloud-based recall tools.

## Primary use cases
- “Find the exact sentence I read in Safari this morning.”
- “Recall the error message from the terminal I saw 20 minutes ago.”
- “Search for the name in a chat app without storing screenshots.”

## Success metrics
- Time to first capture after start: < 3 seconds.
- App switch capture: 95% of switches captured within 1 second.
- Idle CPU: < 0.2% sustained; active CPU < 2% typical.
- RAM footprint: < 120 MB steady state.
- Search latency: < 150 ms for typical queries on 30 days of data.
- Disk growth: < 50 MB per 30 days (text-only).

## Scope and versions
### v0 (CLI-only, first shippable)
- Background daemon that captures text.
- CLI commands for install/start/stop/status/search/export/purge.
- Local SQLite storage with FTS5.
- Permissions onboarding flow via CLI.

### v1 (small menu bar app)
- Status indicator, pause/resume, last capture timestamp (SwiftUI + AppKit).
- Basic search UI (list results, copy text, open app).
- Preferences for retention and ignored apps.

### v1.1 (optional)
- Local HTTP read-only search API for integrations (disabled by default).
- Simple export to JSON/CSV.

## Functional requirements
### Capture
- Capture is event-driven with a periodic idle fallback.
- Accessibility text extraction is the primary source.
- OCR (Vision) runs only when Accessibility yields insufficient text.
- Capture triggers:
  - App switch
  - Window focus change
  - Click
  - Typing pause
  - Scroll stop
  - Clipboard copy
  - Idle fallback (max gap)
- Minimum capture interval per monitor: 200 ms (hard cap).
- Maximum gap between captures during activity: 10 seconds.

### Storage
- Store only text and metadata (timestamp, app, window, source, trigger).
- Use SQLite with FTS5 for fast local search.
- Automatic retention policy with configurable days and max size.
- Full local delete (purge) with confirmation.

### Search
- Keyword search with optional filters:
  - time range
  - app name
  - window title
  - source (accessibility or OCR)
  - trigger type
- Return top results with snippet context and timestamp.
- CLI returns plain text; menu bar app can show a list view.

### Management
- CLI supports install/uninstall (LaunchAgent).
- Start/stop/pause/resume with immediate effect.
- `status` shows last capture time, permissions, and capture mode.
- `doctor` checks permissions and reports missing capabilities.
- All runtime targets (daemon, CLI, menu bar app) are Swift binaries in one native codebase.

## Non-functional requirements
### Performance
- No continuous screen polling; use system event taps and accessibility notifications.
- OCR runs on background queues with strict timeouts.
- Avoid keeping large images in memory.

### Footprint
- Text-only storage; no screenshots on disk.
- Temporary OCR images in memory only; discard immediately after text extraction.
- Disk budget enforced via retention and size caps.

### Privacy and security
- No network calls by default.
- All data stored in user profile; no global shared data.
- Optional encryption at rest (phase 2) using FileProtection + Keychain.

## Platform constraints
- macOS 13.5+ (ScreenCaptureKit stability and modern Accessibility APIs).
- Apple Silicon only (arm64); no x86_64 builds.
- Signed and notarized binary.

## User journeys
### First run (CLI)
1. User runs `screentext install`.
2. Tool prompts for Screen Recording and Accessibility permissions.
3. User grants permissions in System Settings.
4. `screentext start` begins capture; `status` confirms last capture timestamp.

### Search flow (CLI)
1. `screentext search "invoice number" --since 24h --app Safari`.
2. Results show timestamps, app/window, and text snippet.
3. User can copy full text via `--full`.

### Pause/resume
1. `screentext pause` stops capture immediately.
2. `screentext resume` restarts capture without restarting the daemon.

## CLI specification
Working binary name: `screentext`.

Commands:
- `screentext install` - installs LaunchAgent and data directories.
- `screentext uninstall` - stops daemon and removes LaunchAgent and data.
- `screentext start` - starts capture daemon.
- `screentext stop` - stops capture daemon.
- `screentext pause` - pause capture (daemon stays running).
- `screentext resume` - resume capture.
- `screentext status` - show permissions, last capture, queue depth.
- `screentext doctor` - validate permissions and system readiness.
- `screentext search <query>` - search text history.
- `screentext export --format json|csv --since 7d` - export text.
- `screentext purge --older-than 30d` - delete old data.
- `screentext config set <key> <value>` - update config.

Example output (status):
```
Status: running
Last capture: 2026-02-21T10:12:04-0800
Permissions: screen_recording=granted, accessibility=granted
Capture mode: event-driven (idle gap 10s)
Data size: 12.4 MB (retention 30 days)
```

## Architecture overview
```
Event Sources (NSWorkspace, AXObserver, CGEventTap)
  -> Capture Controller (debounce + trigger policy)
     -> Text Extractor
        - Accessibility walker (primary)
        - Vision OCR (fallback)
     -> Storage (SQLite + FTS5)
CLI / UI -> Query layer -> Storage
```

## Capture strategy (event-driven)
### Triggers
- App switch (NSWorkspace notifications)
- Window focus change (AXObserver notifications)
- Click (CGEventTap)
- Typing pause (key events + debounce)
- Scroll stop (scroll events + debounce)
- Clipboard copy (NSPasteboard change count)
- Idle fallback (timer)

### Debounce and guardrails
- Minimum interval per monitor: 200 ms.
- Maximum gap: 10 seconds while active; 30 seconds while idle.
- If system is idle and screen is static, capture once per idle gap.

### Monitor selection
- Capture only the monitor containing the focused window.
- Other monitors get idle fallback captures only (text-only).

## Text extraction
### Accessibility-first path
- Use `AXUIElementCreateSystemWide` and focused window queries.
- Traverse AX tree with a 200 ms timeout.
- Extract visible text, role, and selected value attributes.
- If extracted text length < threshold or empty, fall back to OCR.

### OCR fallback
- Use ScreenCaptureKit to capture focused window or display region.
- Use Vision `VNRecognizeTextRequest` with `recognitionLevel = .fast` by default.
- Language detection uses system locale plus user overrides.
- OCR timeout: 500 ms; if exceeded, skip and log for diagnostics.

### Dedup and noise reduction
- Text hash per capture; if identical to previous capture for same window within 2 seconds, skip insert.
- Optional low-confidence filter for OCR results (default: drop if < 0.3 confidence).

## Data model
SQLite schema (draft):
```
CREATE TABLE captures (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  timestamp TEXT NOT NULL,
  app_name TEXT NOT NULL,
  window_title TEXT,
  bundle_id TEXT,
  text_source TEXT NOT NULL,      -- accessibility | ocr
  capture_trigger TEXT NOT NULL,  -- app_switch | click | typing_pause | scroll_stop | clipboard | idle
  display_id TEXT,
  text_hash TEXT,
  text_length INTEGER,
  created_at TEXT NOT NULL
);

CREATE VIRTUAL TABLE captures_fts USING fts5(
  text_content,
  content='captures',
  content_rowid='id'
);

CREATE TABLE capture_text (
  capture_id INTEGER PRIMARY KEY,
  text_content TEXT NOT NULL,
  FOREIGN KEY(capture_id) REFERENCES captures(id) ON DELETE CASCADE
);

CREATE INDEX idx_captures_timestamp ON captures(timestamp);
CREATE INDEX idx_captures_app ON captures(app_name);
CREATE INDEX idx_captures_source ON captures(text_source);
```

## Storage layout
Default data directory:
- `~/Library/Application Support/ScreenText/`
  - `screen_text.db`
  - `config.json`
  - `logs/`

No images or audio files stored by default.

## Configuration
Configuration file: `config.json` (JSON for simplicity).

Key settings:
- `retention_days` (default 30)
- `max_db_size_mb` (default 200)
- `idle_gap_seconds` (default 30)
- `active_gap_seconds` (default 10)
- `min_capture_interval_ms` (default 200)
- `ocr_enabled` (default true)
- `ocr_confidence_threshold` (default 0.3)
- `ignored_apps` (array of bundle IDs)

## Permissions and entitlements
- Screen Recording permission required for OCR capture.
- Accessibility permission required for AX text extraction.
- If only Accessibility is granted, still run (OCR disabled).
- If only Screen Recording is granted, run OCR-only mode (explicit warning).

## Security and privacy
- All data stays local; no network calls by default.
- Logs contain no captured text by default; only metadata.
- Optional encrypted database at rest (future): SQLCipher or per-file encryption.
- Clear, explicit pause mode that stops all capture immediately.

## Reliability and health
- Health checks exposed via CLI `status` (last capture timestamp, queue depth).
- If no captures in > 60 seconds while active, mark status as degraded.
- Automatic restart of capture loop if event tap fails.

## Observability
- OSLog categories: capture, ocr, storage, permissions.
- CLI `logs --tail` for recent errors.
- No telemetry or analytics in v1.

## Testing plan
### Unit tests
- Debounce logic for triggers.
- Text dedup hashing.
- SQLite insert/query correctness.

### Integration tests
- Accessibility extraction from TextEdit and Safari.
- OCR fallback on image-only windows (Preview).
- Retention cleanup correctness.

### E2E (manual or scripted)
- App switch capture within 1 second.
- Typing pause capture shows the final text.
- Search returns correct snippets by app filter.
- Permission denial paths behave predictably.

## Distribution and installation
- Signed and notarized binary.
- Homebrew formula (`brew install screentext`).
- LaunchAgent plist created by `screentext install`.
- Uninstall removes LaunchAgent, logs, and database if requested.

## Rollout plan
Phase 0 (prototype):
- Event-driven capture loop with Accessibility-only.
- SQLite storage + FTS query.

Phase 1 (v0 CLI):
- OCR fallback (Vision).
- CLI commands + LaunchAgent.
- Basic retention.

Phase 2 (v1 menu bar app):
- Status UI, pause/resume, quick search view.
- Preferences for retention and ignored apps.

Phase 3 (v1.1 optional):
- Local read-only search API.
- Export improvements.

## Risks and mitigations
- Accessibility text incomplete in some apps: OCR fallback with strict limits.
- OCR cost on large screens: downscale and region-of-interest capture.
- Permission friction: CLI doctor + clear documentation.
- App Nap / background throttling: use process activity assertions.

## Open questions
- Minimum macOS version: 13.5 vs 14.0 for best ScreenCaptureKit reliability.
- Default retention days (7 vs 30) and size caps.
- Preferred config format (JSON vs TOML).
- Whether to include a local read-only HTTP API in v1.

## Appendix: v1 menu bar app scope
- Show running status, last capture timestamp, and warnings.
- Pause/resume button.
- Quick search input with last 20 results.
- Preferences: retention, ignored apps, OCR on/off.
