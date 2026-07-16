from __future__ import annotations

import tomllib
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class VoiceProfile:
    id: str
    display_name: str
    voice_presentation: str
    kokoro_voice: str
    sarvam_fallback_speaker: str


@dataclass(frozen=True)
class VoiceCatalog:
    language: str
    default_voice_id: str
    voices: dict[str, VoiceProfile]

    def require(self, voice_id: str | None) -> VoiceProfile:
        resolved = voice_id or self.default_voice_id
        try:
            return self.voices[resolved]
        except KeyError as error:
            raise ValueError(f"Unsupported voice_id: {resolved}") from error


def load_voice_catalog(path: str = "config/voices/hindi_v1.toml") -> VoiceCatalog:
    resolved = Path(path)
    if not resolved.is_absolute():
        for parent in Path(__file__).resolve().parents:
            candidate = parent / path
            if candidate.is_file():
                resolved = candidate
                break
    with resolved.open("rb") as file:
        data = tomllib.load(file)

    catalog_data = data.get("catalog", {})
    voices: dict[str, VoiceProfile] = {}
    for entry in data.get("voices", []):
        profile = VoiceProfile(
            id=str(entry["id"]),
            display_name=str(entry["display_name"]),
            voice_presentation=str(entry["voice_presentation"]),
            kokoro_voice=str(entry["kokoro_voice"]),
            sarvam_fallback_speaker=str(entry["sarvam_fallback_speaker"]),
        )
        if profile.id in voices:
            raise ValueError(f"Duplicate voice_id: {profile.id}")
        voices[profile.id] = profile

    catalog = VoiceCatalog(
        language=str(catalog_data["language"]),
        default_voice_id=str(catalog_data["default_voice_id"]),
        voices=voices,
    )
    catalog.require(catalog.default_voice_id)
    return catalog
