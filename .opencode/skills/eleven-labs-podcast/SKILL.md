---
name: eleven-labs-podcast
description: |
  Create podcast audio from a text file with ElevenLabs APIs.

  Triggers when user mentions:
  - "eleven labs podcast"
  - "create a podcast from a text file"
  - "turn script into podcast audio"
---

## Quick Usage (Already Configured)

### 1) List available voices
```bash
bash .opencode/skills/eleven-labs-podcast/scripts/list-voices.sh
```

### 2) Generate podcast audio from a text file
```bash
python3 .opencode/skills/eleven-labs-podcast/scripts/create-podcast.py "notes/episode-01.txt" --mode auto --output "notes/episode-01.mp3"
```

### 3) Force dialogue mode (HOST/GUEST)
```bash
python3 .opencode/skills/eleven-labs-podcast/scripts/create-podcast.py "notes/dialogue.txt" --mode dialogue
```

## Input Format

- `auto` mode uses dialogue when it sees `HOST:` or `GUEST:` lines; otherwise it uses narration (`tts`).
- `tts` mode narrates the full file with one voice.
- `dialogue` mode treats each non-empty line as one turn.
- In dialogue mode, unprefixed lines alternate between host and guest voices.

## What This Skill Loads

- Credentials are loaded from `.opencode/skills/eleven-labs-podcast/.env`.
- Required: `ELEVEN_LABS_API`.
- Optional defaults come from `.env.example`.
- API calls used by this skill:
  - `GET /v1/voices`
  - `POST /v1/text-to-speech/{voice_id}`
  - `POST /v1/text-to-dialogue`

## Common Gotchas

- If you get a `401` or `403`, verify the API key and key scope.
- `mp3_44100_192` requires a higher ElevenLabs tier; default is `mp3_44100_128`.
- For dialogue mode, split very long lines into shorter turns for best quality.

## First-Time Setup (If Not Configured)

1. Copy `.opencode/skills/eleven-labs-podcast/.env.example` to `.opencode/skills/eleven-labs-podcast/.env`.
2. Set `ELEVEN_LABS_API`.
3. Optionally set your preferred voice IDs and model IDs.
