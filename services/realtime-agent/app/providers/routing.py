from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True)
class ProviderRoute:
    stt: str
    llm: str
    tts: str
    tts_fallback: str = ""


@dataclass(frozen=True)
class MemoryStrategyRoute:
    """One selected strategy per memory stage for a language-scoped session."""

    retrieval: str
    reranker: str
    planner: str


@dataclass(frozen=True)
class ProviderRouting:
    default: ProviderRoute
    languages: dict[str, ProviderRoute]
    memory_default: MemoryStrategyRoute
    memory_languages: dict[str, MemoryStrategyRoute]

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "ProviderRouting":
        provider_data = data.get("providers", {})
        defaults = provider_data.get("default", {})
        language_data = provider_data.get("languages", {})
        memory_data = data.get("memory", {})
        memory_default_data = memory_data.get("default", {})
        memory_language_data = memory_data.get("languages", {})
        memory_default = MemoryStrategyRoute(
            retrieval=str(memory_default_data.get("retrieval", "deterministic")),
            reranker=str(memory_default_data.get("reranker", "deterministic")),
            planner=str(memory_default_data.get("planner", "deterministic")),
        )

        return cls(
            default=ProviderRoute(
                stt=defaults["stt"],
                llm=defaults["llm"],
                tts=defaults["tts"],
                tts_fallback=str(defaults.get("tts_fallback", "")),
            ),
            languages={
                language: ProviderRoute(
                    stt=route.get("stt", defaults["stt"]),
                    llm=route.get("llm", defaults["llm"]),
                    tts=route.get("tts", defaults["tts"]),
                    tts_fallback=str(route.get("tts_fallback", defaults.get("tts_fallback", ""))),
                )
                for language, route in language_data.items()
            },
            memory_default=memory_default,
            memory_languages={
                language: MemoryStrategyRoute(
                    retrieval=str(route.get("retrieval", memory_default.retrieval)),
                    reranker=str(route.get("reranker", memory_default.reranker)),
                    planner=str(route.get("planner", memory_default.planner)),
                )
                for language, route in memory_language_data.items()
            },
        )

    def for_language(self, language: str) -> ProviderRoute:
        return self.languages.get(language, self.default)

    def memory_for_language(self, language: str) -> MemoryStrategyRoute:
        return self.memory_languages.get(language, self.memory_default)
