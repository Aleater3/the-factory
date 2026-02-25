---
name: render
description: |
  Run Render API actions with a local API key loaded from this skill.

  Triggers when user mentions:
  - "do x on render"
  - "render api"
  - "manage render service"
---

## Quick Usage (Already Configured)

### 1) Run any Render API request
```bash
bash .opencode/skills/render/scripts/render-api.sh GET /services
```

### 2) Trigger a deploy for a service
```bash
bash .opencode/skills/render/scripts/render-api.sh POST "/services/<service-id>/deploys" "{}"
```

### 3) Suspend a service
```bash
bash .opencode/skills/render/scripts/render-api.sh POST "/services/<service-id>/suspend" "{}"
```

## What This Skill Loads

- Credentials are loaded from `.opencode/skills/render/.env`.
- Required: `RENDER_API_KEY`.
- Optional: `RENDER_API_BASE` (defaults to `https://api.render.com/v1`).

## Common Gotchas

- Render API paths must start with `/` (example: `/services`).
- For `POST`/`PATCH`/`PUT`, pass a JSON body string as the third argument.
- Keep `.env` local only; never commit API keys.

## First-Time Setup (If Not Configured)

1. Copy `.opencode/skills/render/.env.example` to `.opencode/skills/render/.env`.
2. Set `RENDER_API_KEY`.
3. Test with:
```bash
bash .opencode/skills/render/scripts/render-api.sh GET /owners
```
