# OpenWork landing embed plan

This note tracks the proposed approach for embedding a live OpenWork demo in the landing site and defaulting to a cloud OpenCode server.

## Proposal snapshot
- Use Next.js (Vercel) to add a `/demo` route and embed the OpenWork Web UI (iframe first).
- Default the server picker to a hosted OpenCode instance via envs.
- Use a server proxy route to avoid exposing credentials in the browser.

Suggested envs:

```
NEXT_PUBLIC_OPENCODE_SERVER_URL=https://opencode-demo.openwork.ai
NEXT_PUBLIC_OPENCODE_SERVER_LABEL=OpenWork Cloud Demo
NEXT_PUBLIC_OPENCODE_PROXY_URL=/api/opencode
OPENCODE_SERVER_USERNAME=opencode
OPENCODE_SERVER_PASSWORD=change-me
```

## OpenCode demo server
- Run `opencode web` or `opencode serve` on a small VPS.
- Set `OPENCODE_SERVER_PASSWORD` and allow CORS for `https://openwork.ai`.
- Lock down permissions in `opencode.json` (deny `bash` and `edit`).

## VPS recommendation (best value)
- Hetzner Cloud shared plans: CX23 (2 vCPU / 4 GB) from ~EUR 3.49/mo.
- DigitalOcean Basic: 1 vCPU / 1 GB at $6/mo.

Recommendation: start with Hetzner CX23 or CPX11 for a low-cost demo.

## Landing repo PR
- https://github.com/different-ai/openwork-landing/pull/8
