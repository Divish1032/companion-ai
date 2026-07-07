from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True)
class ProviderRoute:
    stt: str
    llm: str
    tts: str


@dataclass(frozen=True)
class ProviderRouting:
    default: ProviderRoute
    languages: dict[str, ProviderRoute]

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "ProviderRouting":
        provider_data = data.get("providers", {})
        defaults = provider_data.get("default", {})
        language_data = provider_data.get("languages", {})

        return cls(
            default=ProviderRoute(
                stt=defaults["stt"],
                llm=defaults["llm"],
                tts=defaults["tts"],
            ),
            languages={
                language: ProviderRoute(
                    stt=route.get("stt", defaults["stt"]),
                    llm=route.get("llm", defaults["llm"]),
                    tts=route.get("tts", defaults["tts"]),
                )
                for language, route in language_data.items()
            },
        )

    def for_language(self, language: str) -> ProviderRoute:
        return self.languages.get(language, self.default)
