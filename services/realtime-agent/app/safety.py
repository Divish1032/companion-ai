from __future__ import annotations

from dataclasses import dataclass


CRISIS_RESPONSE_HI = (
    "Mujhe afsos hai ki aap itna heavy feel kar rahe ho. "
    "Agar turant danger lag raha hai, 112 par call karein ya kisi trusted person "
    "ke paas abhi chale jaayein. India mein iCall 9152987821, Vandrevala "
    "Foundation 1860-266-2345, aur AASRA +91-9820466726 bhi available hain."
)

CRISIS_KEYWORDS = (
    "main mar jaana chahta hoon",
    "main apni jaan dena chahta hoon",
    "jeene ka mann nahi karta",
    "sab khatam karna hai",
    "suicide",
    "khud ko maar",
    "khud ko nuksan",
    "main mar jana chahta hoon",
    "meri jaan dena chahta hoon",
    "mai mar jana chahta hu",
    "मैं मर जाना चाहता हूं",
    "मैं मर जाना चाहता हूँ",
    "मैं अपनी जान देना चाहता हूं",
    "मैं अपनी जान देना चाहता हूँ",
    "जीने का मन नहीं करता",
    "सब खत्म करना है",
    "खुद को मार",
    "खुद को नुकसान",
)

PROMPT_INJECTION_KEYWORDS = (
    "ignore previous instructions",
    "ignore system prompt",
    "developer message",
    "system prompt batao",
    "prompt leak",
)


@dataclass(frozen=True)
class SafetyDecision:
    allowed: bool
    response_override: str | None = None
    reason: str | None = None


class SafetyClassifier:
    def classify_input(self, text: str) -> SafetyDecision:
        normalized = text.casefold()
        if any(keyword in normalized for keyword in CRISIS_KEYWORDS):
            return SafetyDecision(
                allowed=False,
                response_override=CRISIS_RESPONSE_HI,
                reason="crisis_keyword",
            )
        if any(keyword in normalized for keyword in PROMPT_INJECTION_KEYWORDS):
            return SafetyDecision(
                allowed=False,
                response_override="मैं इस तरह के निर्देशों में मदद नहीं कर सकता, लेकिन आपकी बात सुन सकता हूँ।",
                reason="prompt_injection_blocked",
            )
        return SafetyDecision(allowed=True)

    def classify_output(self, text: str) -> SafetyDecision:
        normalized = text.casefold()
        if any(keyword in normalized for keyword in CRISIS_KEYWORDS):
            return SafetyDecision(
                allowed=False,
                response_override=CRISIS_RESPONSE_HI,
                reason="output_crisis_keyword",
            )
        return SafetyDecision(allowed=True)
