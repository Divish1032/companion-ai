from __future__ import annotations

import asyncio
import json
import time
import urllib.error
import urllib.request
from collections.abc import AsyncIterator

from app.providers.interfaces import LLMMessage, LLMProvider, LLMToken


class LLMProviderUnavailable(RuntimeError):
    pass


class PersonaLLMProvider(LLMProvider):
    provider_name = "persona_local"
    model_name = "hindi_companion_rules_v1"

    async def stream(
        self,
        messages: list[LLMMessage],
        language: str,
        *,
        max_output_chars: int,
    ) -> AsyncIterator[LLMToken]:
        started = time.perf_counter()
        response = _clip_text(_persona_response(messages), max_output_chars=max_output_chars)
        for chunk in _chunk_text(response, chunk_chars=36):
            await asyncio.sleep(0)
            yield LLMToken(
                text=chunk,
                provider=self.provider_name,
                model=self.model_name,
                latency_ms=round((time.perf_counter() - started) * 1000),
            )


class SarvamChatLLMProvider(LLMProvider):
    provider_name = "sarvam"

    def __init__(
        self,
        *,
        api_key: str,
        model: str = "sarvam-30b",
        base_url: str = "https://api.sarvam.ai/v1",
        timeout_seconds: float = 12.0,
    ) -> None:
        if not api_key:
            raise LLMProviderUnavailable("AGENT_SARVAM_API_KEY is required for Sarvam LLM.")
        self.api_key = api_key
        self.model_name = model
        self.base_url = base_url.rstrip("/")
        self.timeout_seconds = timeout_seconds

    async def stream(
        self,
        messages: list[LLMMessage],
        language: str,
        *,
        max_output_chars: int,
    ) -> AsyncIterator[LLMToken]:
        started = time.perf_counter()
        text = await asyncio.to_thread(
            self._complete,
            [
                {"role": message.role, "content": message.content}
                for message in messages
                if message.content.strip()
            ],
            max_output_chars,
        )
        for chunk in _chunk_text(text, chunk_chars=48):
            yield LLMToken(
                text=chunk,
                provider=self.provider_name,
                model=self.model_name,
                latency_ms=round((time.perf_counter() - started) * 1000),
            )

    def _complete(self, messages: list[dict[str, str]], max_output_chars: int) -> str:
        payload = json.dumps(
            {
                "model": self.model_name,
                "messages": messages,
                "max_tokens": max(32, min(160, max_output_chars // 3)),
                "reasoning_effort": None,
            }
        ).encode("utf-8")
        request = urllib.request.Request(
            f"{self.base_url}/chat/completions",
            data=payload,
            headers={
                "api-subscription-key": self.api_key,
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json",
            },
            method="POST",
        )
        try:
            with urllib.request.urlopen(request, timeout=self.timeout_seconds) as response:
                decoded = json.loads(response.read().decode("utf-8"))
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as error:
            raise LLMProviderUnavailable(f"Sarvam LLM request failed: {error}") from error

        choices = decoded.get("choices") if isinstance(decoded, dict) else None
        if not isinstance(choices, list) or not choices:
            raise LLMProviderUnavailable("Sarvam LLM response did not include choices.")
        first = choices[0]
        message = first.get("message") if isinstance(first, dict) else None
        content = message.get("content") if isinstance(message, dict) else None
        if not isinstance(content, str) or not content.strip():
            raise LLMProviderUnavailable("Sarvam LLM response did not include message content.")
        return _clip_text(content.strip(), max_output_chars=max_output_chars)


def _latest_user_text(messages: list[LLMMessage]) -> str:
    for message in reversed(messages):
        if message.role == "user" and message.content.strip():
            return message.content.strip()
    return ""


def _persona_response(messages: list[LLMMessage]) -> str:
    user_text = _latest_user_text(messages)
    normalized = user_text.casefold()
    memory_text = "\n".join(
        message.content for message in messages if message.role == "system"
    ).casefold()
    remembered_name = _remembered_name(memory_text)
    if remembered_name and any(
        phrase in normalized
        for phrase in (
            "mera naam",
            "my name",
            "naam kya",
            "kya yaad",
            "remember me",
            "mujhe kya bulate",
        )
    ):
        return f"Haan, mujhe yaad hai ki aapko {remembered_name} bulana hai."
    if "hinglish" in memory_text and any(
        phrase in normalized for phrase in ("kaise baat", "kis style", "remember")
    ):
        return "Haan, main Hinglish mein hi natural tareeke se baat karunga."
    if any(word in normalized for word in ("mood", "theek nahi", "udaas", "pareshan", "off")):
        return (
            "Samajh raha hoon. Aaj mood theek nahi hai toh thoda dheere chalte hain. "
            "Ek chhoti si baat batao, sabse zyada heavy kya lag raha hai?"
        )
    if any(word in normalized for word in ("namaste", "hello", "hi", "haan")):
        return "Namaste. Main yahin hoon, aaram se bolo. Aaj dil mein kya chal raha hai?"
    return "Haan, main sun raha hoon. Thoda aur batao, main bina judge kiye saath hoon."


def _remembered_name(memory_text: str) -> str | None:
    marker = "user prefers to be called "
    start = memory_text.find(marker)
    if start < 0:
        return None
    value = memory_text[start + len(marker) :].split(".", 1)[0].strip()
    if not value or len(value) > 32:
        return None
    return value.title()


def _chunk_text(text: str, *, chunk_chars: int) -> list[str]:
    words = text.split()
    chunks: list[str] = []
    current = ""
    for word in words:
        candidate = f"{current} {word}".strip()
        if current and len(candidate) > chunk_chars:
            chunks.append(current + " ")
            current = word
        else:
            current = candidate
    if current:
        chunks.append(current)
    return chunks or [""]


def _clip_text(text: str, *, max_output_chars: int) -> str:
    if len(text) <= max_output_chars:
        return text
    boundary = max(text.rfind(marker, 0, max_output_chars) for marker in (".", "?", "!", "।"))
    if boundary < max_output_chars // 2:
        boundary = text.rfind(" ", 0, max_output_chars)
    if boundary <= 0:
        boundary = max_output_chars
    return text[:boundary].strip()
