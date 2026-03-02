#!/usr/bin/env python3
"""Create podcast audio from a text file using ElevenLabs APIs."""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


HOST_GUEST_PATTERN = re.compile(r"^(host|guest)\s*:\s*(.+)$", re.IGNORECASE)


def load_env_file(env_path: Path) -> None:
    if not env_path.exists():
        return

    for raw_line in env_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip()
        if (
            len(value) >= 2
            and ((value[0] == '"' and value[-1] == '"') or (value[0] == "'" and value[-1] == "'"))
        ):
            value = value[1:-1]
        os.environ.setdefault(key, value)


def post_json(url: str, payload: dict, api_key: str) -> bytes:
    request = urllib.request.Request(
        url=url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json", "xi-api-key": api_key},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=180) as response:
            return response.read()
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"ElevenLabs API error {exc.code}: {detail}") from exc


def build_dialogue_inputs(lines: list[str], host_voice_id: str, guest_voice_id: str) -> list[dict[str, str]]:
    inputs: list[dict[str, str]] = []
    alternating_turn = 0

    for raw_line in lines:
        line = raw_line.strip()
        if not line:
            continue

        match = HOST_GUEST_PATTERN.match(line)
        if match:
            speaker = match.group(1).lower()
            text = match.group(2).strip()
            if not text:
                continue
            voice_id = host_voice_id if speaker == "host" else guest_voice_id
        else:
            text = line
            voice_id = host_voice_id if alternating_turn % 2 == 0 else guest_voice_id
            alternating_turn += 1

        inputs.append({"text": text, "voice_id": voice_id})

    return inputs


def resolve_mode(lines: list[str], requested_mode: str) -> str:
    if requested_mode != "auto":
        return requested_mode
    for raw_line in lines:
        if HOST_GUEST_PATTERN.match(raw_line.strip()):
            return "dialogue"
    return "tts"


def main() -> int:
    script_dir = Path(__file__).resolve().parent
    skill_dir = script_dir.parent
    env_path = skill_dir / ".env"
    load_env_file(env_path)

    parser = argparse.ArgumentParser(description="Create podcast audio from a text file with ElevenLabs.")
    parser.add_argument("input_file", help="Path to a source text file.")
    parser.add_argument("--output", help="Output audio path (defaults to input filename with .mp3).")
    parser.add_argument("--mode", choices=["auto", "tts", "dialogue"], default="auto")
    parser.add_argument("--api-base", default=os.getenv("ELEVEN_LABS_API_BASE", "https://api.elevenlabs.io"))
    parser.add_argument("--output-format", default=os.getenv("ELEVEN_LABS_OUTPUT_FORMAT", "mp3_44100_128"))
    parser.add_argument("--voice-id", default=os.getenv("ELEVEN_LABS_VOICE_ID", "JBFqnCBsd6RMkjVDRZzb"))
    parser.add_argument("--host-voice-id", default=os.getenv("ELEVEN_LABS_HOST_VOICE_ID", "JBFqnCBsd6RMkjVDRZzb"))
    parser.add_argument("--guest-voice-id", default=os.getenv("ELEVEN_LABS_GUEST_VOICE_ID", "Aw4FAjKCGjjNkVhN1Xmq"))
    parser.add_argument("--tts-model-id", default=os.getenv("ELEVEN_LABS_TTS_MODEL_ID", "eleven_multilingual_v2"))
    parser.add_argument("--dialogue-model-id", default=os.getenv("ELEVEN_LABS_DIALOGUE_MODEL_ID", "eleven_v3"))
    args = parser.parse_args()

    api_key = os.getenv("ELEVEN_LABS_API") or os.getenv("ELEVENLABS_API_KEY")
    if not api_key:
        print(
            f"Missing ELEVEN_LABS_API in {env_path}. Copy .env.example to .env and set ELEVEN_LABS_API.",
            file=sys.stderr,
        )
        return 1

    source_path = Path(args.input_file).expanduser()
    if not source_path.exists():
        print(f"Input file does not exist: {source_path}", file=sys.stderr)
        return 1

    source_text = source_path.read_text(encoding="utf-8").strip()
    if not source_text:
        print(f"Input file is empty: {source_path}", file=sys.stderr)
        return 1

    output_path = Path(args.output).expanduser() if args.output else source_path.with_suffix(".mp3")
    output_path.parent.mkdir(parents=True, exist_ok=True)

    lines = source_text.splitlines()
    mode = resolve_mode(lines, args.mode)
    output_format_query = urllib.parse.urlencode({"output_format": args.output_format})
    api_base = args.api_base.rstrip("/")

    if mode == "tts":
        endpoint = (
            f"{api_base}/v1/text-to-speech/{urllib.parse.quote(args.voice_id, safe='')}?{output_format_query}"
        )
        payload = {"text": source_text, "model_id": args.tts_model_id}
    else:
        inputs = build_dialogue_inputs(lines, args.host_voice_id, args.guest_voice_id)
        if not inputs:
            print("No dialogue inputs found in the source file.", file=sys.stderr)
            return 1
        endpoint = f"{api_base}/v1/text-to-dialogue?{output_format_query}"
        payload = {"inputs": inputs, "model_id": args.dialogue_model_id}

    try:
        audio_bytes = post_json(endpoint, payload, api_key)
    except RuntimeError as error:
        print(str(error), file=sys.stderr)
        return 1

    output_path.write_bytes(audio_bytes)
    print(f"Created podcast audio: {output_path} (mode={mode}, format={args.output_format})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
