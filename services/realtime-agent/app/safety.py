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
    "jeene ka mann nahi karta",
    "sab khatam karna hai",
    "suicide",
    "khud ko maar",
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
        return SafetyDecision(allowed=True)
