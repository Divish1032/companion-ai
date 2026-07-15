from __future__ import annotations

import asyncio
import json
import time
import urllib.error
import urllib.request
from collections.abc import AsyncIterator, Iterator

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
        events = self._stream_events(
            [
                {"role": message.role, "content": message.content}
                for message in messages
                if message.content.strip()
            ],
            max_output_chars,
        )
        sentinel = object()
        while True:
            event = await asyncio.to_thread(next, events, sentinel)
            if event is sentinel:
                break
            text, usage = event
            yield LLMToken(
                text=text,
                provider=self.provider_name,
                model=self.model_name,
                latency_ms=round((time.perf_counter() - started) * 1000),
                input_tokens=usage[0] if usage else 0,
                cached_input_tokens=usage[1] if usage else 0,
                output_tokens=usage[2] if usage else 0,
                usage_reported=usage is not None,
            )

    def _stream_events(
        self, messages: list[dict[str, str]], max_output_chars: int
    ) -> Iterator[tuple[str, tuple[int, int, int] | None]]:
        """Yield Sarvam OpenAI-compatible SSE deltas and the terminal usage block.

        The final usage event intentionally has an empty text delta.  Consumers
        can therefore reconcile provider-reported token usage even when the
        provider does not attach usage to a content chunk.
        """
        payload = json.dumps(
            {
                "model": self.model_name,
                "messages": messages,
                "max_tokens": max(32, min(160, max_output_chars // 3)),
                "reasoning_effort": None,
                "stream": True,
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
                received_content = False
                for raw_line in response:
                    line = raw_line.decode("utf-8").strip()
                    if not line.startswith("data:"):
                        continue
                    data = line.removeprefix("data:").strip()
                    if data == "[DONE]":
                        break
                    try:
                        decoded = json.loads(data)
                    except json.JSONDecodeError as error:
                        raise LLMProviderUnavailable("Sarvam LLM returned invalid stream data.") from error
                    if not isinstance(decoded, dict):
                        continue
                    usage = _sarvam_usage(decoded.get("usage"))
                    choices = decoded.get("choices")
                    if isinstance(choices, list) and choices:
                        first = choices[0]
                        delta = first.get("delta") if isinstance(first, dict) else None
                        content = delta.get("content") if isinstance(delta, dict) else None
                        if isinstance(content, str) and content:
                            received_content = True
                            yield content, None
                    if usage is not None:
                        yield "", usage
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as error:
            raise LLMProviderUnavailable("Sarvam LLM request failed.") from error
        if not received_content:
            raise LLMProviderUnavailable("Sarvam LLM stream did not include content.")


def _sarvam_usage(value: object) -> tuple[int, int, int] | None:
    if not isinstance(value, dict):
        return None
    prompt = value.get("prompt_tokens")
    completion = value.get("completion_tokens")
    details = value.get("prompt_tokens_details")
    cached = details.get("cached_tokens", 0) if isinstance(details, dict) else 0
    if not isinstance(prompt, int) or not isinstance(completion, int) or not isinstance(cached, int):
        return None
    return max(0, prompt), max(0, cached), max(0, completion)


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
    receipt_question = _receipt_question(memory_text)
    remembered_name = _remembered_name(memory_text)
    admission_response = _turn_admission_response(memory_text)
    if admission_response:
        return _with_receipt_question(admission_response, receipt_question)
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
        return _with_receipt_question(
            f"Haan, mujhe yaad hai ki aapko {remembered_name} bulana hai.",
            receipt_question,
        )
    if "hinglish" in memory_text and any(
        phrase in normalized for phrase in ("kaise baat", "kis style", "remember")
    ):
        return _with_receipt_question(
            "Haan, main Hinglish mein hi natural tareeke se baat karunga.",
            receipt_question,
        )
    if any(word in normalized for word in ("mood", "theek nahi", "udaas", "pareshan", "off")):
        return _with_receipt_question(
            "Samajh raha hoon. Aaj mood theek nahi hai toh thoda dheere chalte hain. "
            "Ek chhoti si baat batao, sabse zyada heavy kya lag raha hai?",
            receipt_question,
        )
    if any(word in normalized for word in ("namaste", "hello", "hi", "haan")):
        return _with_receipt_question(
            "Namaste. Main yahin hoon, aaram se bolo. Aaj dil mein kya chal raha hai?",
            receipt_question,
        )
    return _with_receipt_question(
        "Haan, main sun raha hoon. Thoda aur batao, main bina judge kiye saath hoon.",
        receipt_question,
    )


def _turn_admission_response(memory_text: str) -> str | None:
    if "[turn_admission]" not in memory_text:
        return None
    if "morning-walk routine" in memory_text:
        return "सुबह की सैर दिन की अच्छी शुरुआत लगती है। आपको टहलना अकेले पसंद है या किसी के साथ?"
    if "their brother is named" in memory_text:
        name = _admission_value(memory_text, "their brother is named ")
        return f"{name}—अच्छा नाम है। आप दोनों काफ़ी करीब हैं?" if name else "आप दोनों काफ़ी करीब हैं?"
    if "their sister is named" in memory_text:
        name = _admission_value(memory_text, "their sister is named ")
        return f"{name}—अच्छा नाम है। आप दोनों काफ़ी करीब हैं?" if name else "आप दोनों काफ़ी करीब हैं?"
    if "preferred name as" in memory_text:
        name = _admission_value(memory_text, "preferred name as ")
        return (
            f"अच्छा {name}, आपसे मिलकर अच्छा लगा। आज आपका दिन कैसा रहा?"
            if name
            else "आपसे मिलकर अच्छा लगा। आज आपका दिन कैसा रहा?"
        )
    if "described this goal:" in memory_text:
        return "यह अच्छा लक्ष्य है। आज इसकी तरफ़ एक छोटा कदम क्या हो सकता है?"
    return None


def _admission_value(memory_text: str, marker: str) -> str | None:
    start = memory_text.find(marker)
    if start < 0:
        return None
    value = memory_text[start + len(marker) :].split(".", 1)[0].strip()
    return value if value and len(value) <= 48 else None


def _receipt_question(memory_text: str) -> str | None:
    if "[memory_receipt]" not in memory_text:
        return None
    if "recurring_work_stressor" in memory_text or "manager pressure" in memory_text:
        return "Kya main office/manager pressure wali baat yaad rakhun?"
    return "Kya main yeh baat yaad rakhun?"


def _with_receipt_question(response: str, receipt_question: str | None) -> str:
    if not receipt_question:
        return response
    if receipt_question.casefold() in response.casefold():
        return response
    return f"{response} {receipt_question}"


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
