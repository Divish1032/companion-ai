from __future__ import annotations

from dataclasses import dataclass
from typing import Literal


MemoryRoute = Literal[
    "none",
    "core_profile",
    "semantic",
    "episodic",
    "summary",
    "safety",
    "broad_safe",
]


@dataclass(frozen=True)
class MemoryRoutingDecision:
    route: MemoryRoute
    confidence: float
    reason: str
    max_blocks: int


_GREETING_ACK = {
    "hi", "hello", "hey", "namaste", "नमस्ते", "haan", "हाँ", "हां",
    "theek", "ठीक", "thik", "ok", "okay", "acha", "अच्छा", "achha",
    "ji", "जी", "good", "badhiya", "बढ़िया", "sahi", "सही",
    "bye", "tata", "टाटा", "goodbye", "alvida", "अलविदा",
    "thanks", "dhanyavad", "धन्यवाद", "shukriya", "शुक्रिया",
    "no", "nahi", "नहीं", "nope",
}

_SAFETY_MARKERS = (
    "suicide", "mar jaana", "mar jana", "mar jaunga", "आत्महत्या",
    "khud ko maar", "khud ko khatam", "jaan dena", "jaan de dunga",
    "marne ka man", "jeene ka man nahi", "kuch bhi kar lunga",
    "self harm", "cut myself", "end my life",
)

_PROFILE_MARKERS = (
    "naam", "नाम", "name", "mera naam", "मेरा नाम", "meri naam",
    "language", "भाषा", "bhasha", "style", "style mein",
    "pasand", "पसंद", "prefer", "preference", "pasand hai",
    "kaise baat", "kaise bol", "kaise jawab", "कैसे बात",
    "chhote jawab", "छोटे जवाब", "lambi baat", "short reply",
    "english", "इंग्लिश", "hindi", "हिंदी", "hinglish",
)

_SEMANTIC_MARKERS = (
    "office", "work", "kaam", "ऑफिस", "काम", "job", "नौकरी",
    "manager", "boss", "मैनेजर", "बॉस", "colleague", "सहकर्मी",
    "meeting", "मीटिंग", "deadline", "डेडलाइन", "project",
    "salary", "सेलरी", "promotion", "प्रमोशन", "resign",
    "team", "टीम", "client", "क्लाइंट", "presentation",
    "family", "परिवार", "ghar", "घर", "home", "mummy",
    "papa", "pita", "मम्मी", "पापा", "पिता", "माँ",
    "bhai", "भाई", "behen", "बहन", "bahan", "dost",
    "friend", "दोस्त", "partner", "पार्टनर", "wife",
    "husband", "pati", "patni", "पति", "पत्नी",
    "rishta", "रिश्ता", "relationship", "shaadi", "शादी",
    "study", "पढ़ाई", "college", "कॉलेज", "school", "स्कूल",
    "exam", "एग्जाम", "result", "रिजल्ट", "teacher",
    "health", "सेहत", "tabiyat", "तबियत", "healthy",
    "exercise", "gym", "जिम", "walk", "टहलना", "yoga",
    "routine", "रूटीन", "roz", "रोज़", "daily", "subah",
    "schedule", "habit", "आदत", "aadat",
    "goal", "लक्ष्य", "target", "टारगेट", "dream",
    "sapna", "सपना", "plan", "प्लान", "future", "भविष्य",
    "tension", "टेंशन", "stress", "chinta", "चिंता",
    "pareshan", "परेशान",
    "problem", "समस्या", "dikkat", "दिक्कत", "issue",
    "change", "बदलाव", "badla", "shift", "move", "naya",
)

_EPISODIC_MARKERS = (
    "kal", "yesterday", "कल", "aaj", "आज", "today",
    "last time", "last week", "last month", "last year",
    "pichli", "पिछली", "pichle", "पिछले", "pichla",
    "kaisa raha", "kaisi rahi", "kaisa tha", "kaisi thi",
    "कैसा रहा", "कैसी रही", "कैसा था", "कैसी थी",
    "how did it go", "how was", "what happened",
    "kya hua", "क्या हुआ", "uska kya hua", "उसका क्या हुआ",
    "interview", "appointment", "exam", "test", "इंटरव्यू",
    "trip", "यात्रा", "journey", "safar", "सफ़र",
    "party", "पार्टी", "event", "function", "occasion",
    "result", "रिजल्ट", "outcome", "नतीजा",
    "yaad hai", "याद है", "remember", "yaad karo",
    "woh din", "वह दिन", "us din", "उस दिन", "tab", "तब",
    "uss time", "उस समय", "us waqt", "pehle", "पहले",
    "pehli baar", "पहली बार", "first time",
    "batao", "बताओ", "tell me", "sunao", "सुनाओ",
    "parso", "परसों", "day after", "day before",
)

_SUMMARY_MARKERS = (
    "summary", "summarize", "kya yaad", "what do you remember",
    "kya kya yaad", "sab kuch batao", "puri kahani",
    "ab tak", "अब तक", "so far", "overall", "overview",
    "pichle mahine", "पिछले महीने", "is hafte", "इस हफ्ते",
    "aaj tak", "आज तक", "kya seekha", "क्या सीखा",
    "kya progress", "क्या प्रोग्रेस",
)

_IMPLICIT_REFERENCE_MARKERS = (
    "woh", "वह", "us", "उस", "unka", "उनका", "unki",
    "ye", "यह", "is", "इस", "iska", "इसका",
    "same", "same thing", "वही", "wahi", "fir se", "फिर से",
    "again", "dobara", "दोबारा",
    "like last time", "jaise pichli baar", "जैसे पिछली बार",
    "pehle jaisa", "पहले जैसा", "as before",
    "woh chiz", "वह चीज़", "that thing",
    "jo bataya tha", "जो बताया था", "jo kaha tha",
    "maine bataya", "मैंने बताया", "maine kaha", "मैंने कहा",
    "tumne kaha", "तुमने कहा", "aapne kaha", "आपने कहा",
    "tumne bataya", "तुमने बताया", "aapne bataya",
)

_TEMPORAL_MARKERS = (
    "kal", "yesterday", "aaj", "today", "कल", "आज",
    "parso", "परसों", "tomorrow",
    "is hafte", "इस हफ्ते", "this week",
    "pichle hafte", "पिछले हफ्ते", "last week",
    "next week", "agale hafte", "अगले हफ्ते",
    "is mahine", "इस महीने", "this month",
    "abhi", "अभी", "just now", "thodi der",
)


def route_memory_query(text: str) -> MemoryRoutingDecision:
    normalized = text.casefold().strip()

    if not normalized or len(normalized) < 2:
        return MemoryRoutingDecision("none", 0.95, "empty_or_tiny", 0)

    # --- Safety (highest priority) ---
    if _contains_any(normalized, _SAFETY_MARKERS):
        return MemoryRoutingDecision("safety", 0.95, "safety_intent", 0)

    # --- Greetings / simple acks ---
    if normalized in _GREETING_ACK:
        return MemoryRoutingDecision("none", 0.95, "greeting_or_ack", 0)
    if len(normalized) <= 6 and _topic_token_count(normalized) == 0:
        return MemoryRoutingDecision("none", 0.90, "single_word_no_topic", 0)

    # --- Core profile: identity, language, preferences ---
    if _contains_any(normalized, _PROFILE_MARKERS):
        return MemoryRoutingDecision("core_profile", 0.88, "profile_or_preference_recall", 3)

    # --- Explicit summary requests ---
    if _contains_any(normalized, _SUMMARY_MARKERS):
        return MemoryRoutingDecision("summary", 0.78, "broad_memory_summary", 6)

    # --- Implicit references to past conversation ---
    if _contains_any(normalized, _IMPLICIT_REFERENCE_MARKERS):
        return MemoryRoutingDecision("episodic", 0.72, "implicit_past_reference", 6)

    # --- Explicit temporal / episodic recall ---
    if _contains_any(normalized, _EPISODIC_MARKERS):
        return MemoryRoutingDecision("episodic", 0.80, "temporal_recall", 6)

    # --- Questions about past ---
    if _question_like(normalized) and _contains_any(normalized, _TEMPORAL_MARKERS):
        return MemoryRoutingDecision("episodic", 0.76, "question_about_past", 6)

    # --- Semantic / durable context ---
    if _contains_any(normalized, _SEMANTIC_MARKERS):
        return MemoryRoutingDecision("semantic", 0.74, "semantic_context", 5)

    return MemoryRoutingDecision("broad_safe", 0.45, "ambiguous_query", 0)


def _topic_token_count(text: str) -> int:
    stop_words = {
        "मैं", "मेरा", "मेरी", "मेरे", "मुझे", "तुम", "आप",
        "है", "हूं", "हूँ", "था", "थी", "थे", "हैं",
        "और", "का", "की", "के", "से", "पर", "को",
        "यह", "वह", "आज", "कल",
        "main", "mera", "meri", "mere", "mujhe",
        "hai", "hain", "tha", "thi", "the",
        "aur", "ka", "ki", "ke", "se", "par", "ko",
        "ye", "woh", "yeh", "aaj", "kal",
        "nahi", "haan", "theek", "acha",
    }
    return len({
        token for token in text.replace("।", " ").replace("?", " ").split()
        if len(token) >= 2 and token not in stop_words
    })


def _contains_any(text: str, needles: tuple[str, ...]) -> bool:
    return any(needle in text for needle in needles)


def _question_like(text: str) -> bool:
    markers = (
        "?", "？",
        "kya", "kaun", "kaise", "kis", "kab", "kahan", "kyun",
        "क्या", "कौन", "कैसे", "किस", "कब", "कहाँ", "क्यों",
        "yaad hai", "remember", "what is", "what was",
        "batana", "बताना", "batao", "बताओ",
        "kya hua", "क्या हुआ",
        "kaisa", "कैसा", "kaisi", "कैसी",
    )
    return any(marker in text for marker in markers)
