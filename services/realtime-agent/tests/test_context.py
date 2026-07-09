from app.context import PromptContextBuilder


def test_prompt_builder_excludes_noisy_replaced_and_duplicate_turns() -> None:
    builder = PromptContextBuilder(
        system_prompt="system",
        initial_context={
            "recent_turns": [
                _turn("t1", "user", "low confidence text", status="final", confidence=0.2),
                _turn("t2", "user", "old noisy text", status="final_replaced"),
                _turn("t3", "assistant", "same reply"),
                _turn("t4", "assistant", "same reply"),
                _turn("t5", "user", "mera naam rahul hai"),
            ],
            "memory_blocks": [],
        },
        max_recent_messages=6,
    )

    messages, diagnostics = builder.build("naam yaad hai?")
    contents = "\n".join(message.content for message in messages)

    assert "low confidence text" not in contents
    assert "old noisy text" not in contents
    assert contents.count("same reply") == 1
    assert messages[-1].role == "user"
    assert messages[-1].content == "[latest_user] naam yaad hai?"
    assert diagnostics["recent_turns_selected"] == 2


def test_prompt_builder_selects_relevant_memory_before_recent_turns() -> None:
    builder = PromptContextBuilder(
        system_prompt="system",
        initial_context={
            "recent_turns": [_turn("t1", "user", "kal ka halka sa turn")],
            "memory_blocks": [
                _memory(
                    "m1",
                    "stable_fact",
                    "preferred_name",
                    "User prefers to be called Rahul.",
                    importance=0.9,
                ),
                _memory(
                    "m2",
                    "session_summary",
                    "previous_session",
                    "User talked about morning walks.",
                    importance=0.35,
                ),
                _memory(
                    "m3",
                    "stable_fact",
                    "unsafe",
                    "User mentioned suicide last week.",
                    importance=0.99,
                ),
            ],
        },
        max_recent_messages=4,
    )

    messages, diagnostics = builder.build("mera naam kya yaad hai?")
    contents = [message.content for message in messages]
    joined = "\n".join(contents)

    assert "User prefers to be called Rahul." in joined
    assert "suicide" not in joined
    assert joined.index("[stable_facts]") < joined.index("[recent_turns]")
    assert diagnostics["memory_blocks_selected"] == 2


def test_prompt_builder_prioritizes_identity_fact_and_caps_summaries() -> None:
    builder = PromptContextBuilder(
        system_prompt="system",
        initial_context={
            "recent_turns": [_turn("t1", "user", "beech ka unrelated turn")],
            "memory_blocks": [
                _memory(
                    "m_name",
                    "stable_fact",
                    "preferred_name",
                    "User prefers to be called Rahul.",
                    importance=0.95,
                ),
                *[
                    _memory(
                        f"m_summary_{i}",
                        "session_summary",
                        "previous_session",
                        f"Summary {i}: unrelated memory text.",
                        importance=0.35,
                    )
                    for i in range(5)
                ],
            ],
        },
        max_recent_messages=4,
        max_memory_blocks=6,
    )

    messages, diagnostics = builder.build("mera naam kya hai?")
    joined = "\n".join(message.content for message in messages)

    assert "User prefers to be called Rahul." in joined
    assert joined.count("Summary") <= 1
    assert diagnostics["memory_blocks_selected"] <= 2


def test_prompt_builder_keeps_context_bounded_and_latest_user_authoritative() -> None:
    builder = PromptContextBuilder(
        system_prompt="system " * 20,
        initial_context={
            "recent_turns": [
                _turn(f"t{i}", "user" if i % 2 else "assistant", "bahut lamba context " * 20)
                for i in range(8)
            ],
            "memory_blocks": [
                _memory(
                    f"m{i}",
                    "stable_fact",
                    "safe_preference",
                    "User explicitly said: mujhe chai pasand hai. " * 8,
                )
                for i in range(8)
            ],
        },
        max_recent_messages=6,
        max_context_chars=900,
        max_memory_blocks=6,
    )

    messages, diagnostics = builder.build("latest sawaal")

    assert sum(len(message.content) for message in messages) <= 900
    assert messages[-1].content == "[latest_user] latest sawaal"
    assert diagnostics["message_count"] == len(messages)


def test_prompt_builder_updates_same_session_history_after_complete_turn() -> None:
    builder = PromptContextBuilder(system_prompt="system", initial_context=[])

    builder.remember_complete_turn("t1", "mera naam rahul hai", "Namaste Rahul")
    messages, _diagnostics = builder.build("naam yaad hai?")
    contents = "\n".join(message.content for message in messages)

    assert "[recent_turns] mera naam rahul hai" in contents
    assert "[recent_turns] Namaste Rahul" in contents
    assert messages[-1].content == "[latest_user] naam yaad hai?"


def _turn(
    turn_id: str,
    role: str,
    text: str,
    *,
    status: str = "final",
    confidence: float | None = 0.9,
) -> dict[str, object]:
    return {
        "turn_id": turn_id,
        "role": role,
        "text": text,
        "status": status,
        "confidence": confidence,
        "created_at_ms": int(turn_id.removeprefix("t") or "0"),
    }


def _memory(
    memory_id: str,
    kind: str,
    label: str,
    content: str,
    *,
    confidence: float = 0.8,
    importance: float = 0.7,
) -> dict[str, object]:
    return {
        "memory_id": memory_id,
        "kind": kind,
        "label": label,
        "content": content,
        "source_turn_ids": ["t1"],
        "source_role": "user",
        "transcript_status": "final",
        "stt_confidence": 0.9,
        "created_at_ms": 1,
        "updated_at_ms": 2,
        "last_used_at_ms": None,
        "confidence_score": confidence,
        "importance_score": importance,
    }
