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
