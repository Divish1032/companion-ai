#!/usr/bin/env python3
"""Agent contract test: consume Dart fixture output, feed to PromptContextBuilder, validate."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import yaml

_this_file = Path(__file__).resolve()
_agent_root = _this_file.parents[1]
_repo_root = _this_file.parents[3]

if str(_agent_root) not in sys.path:
    sys.path.insert(0, str(_agent_root))

from app.context import PromptContextBuilder  # noqa: E402

SYSTEM_PROMPT = (
    "You are a supportive Hindi/Hinglish companion. Keep replies to 1-2 short sentences. "
    "Respond naturally in the user's preferred Indian language."
)


def load_fixture_yaml(fixture_id: str) -> dict | None:
    fixture_dir = _repo_root / "evaluation" / "memory" / "fixtures"
    yaml_path = fixture_dir / f"{fixture_id}.yaml"
    if not yaml_path.exists():
        return None
    with open(yaml_path, encoding="utf-8") as fh:
        return yaml.safe_load(fh)


def run_agent_contract(contract_path: str, fixture_path: str | None = None) -> tuple[bool, dict]:
    with open(contract_path, encoding="utf-8") as fh:
        contract = json.load(fh)
    fixture_id = contract.get("fixture_id", "unknown")

    fixture = None
    if fixture_path:
        with open(fixture_path, encoding="utf-8") as fh:
            fixture = yaml.safe_load(fh)
    else:
        fixture = load_fixture_yaml(fixture_id)

    agent_expect = fixture.get("agent_context_expect") if fixture else None

    memory_blocks = contract.get("memory_blocks", [])

    builder = PromptContextBuilder(
        system_prompt=SYSTEM_PROMPT,
        initial_context={"recent_turns": [], "memory_blocks": memory_blocks},
        max_memory_blocks=6,
    )

    query_text = fixture.get("query", {}).get("text", "") if fixture else ""
    messages, diagnostics = builder.build(query_text)
    prompt_text = "\n".join(message.content for message in messages)

    passed = True
    failures = []

    if agent_expect:
        must_contain_labels = agent_expect.get("must_contain_labels", [])
        for label in must_contain_labels:
            if label not in prompt_text:
                passed = False
                failures.append(f"expected label '{label}' in prompt context")

        must_not_contain_labels = agent_expect.get("must_not_contain_labels", [])
        for label in must_not_contain_labels:
            if label in prompt_text:
                passed = False
                failures.append(f"forbidden label '{label}' found in prompt context")

        must_contain_text = agent_expect.get("must_contain_text", [])
        for fragment in must_contain_text:
            if fragment not in prompt_text:
                passed = False
                failures.append("expected text fragment in prompt context (redacted)")

        must_not_contain_text = agent_expect.get("must_not_contain_text", [])
        for fragment in must_not_contain_text:
            if fragment in prompt_text:
                passed = False
                failures.append("forbidden text fragment found in prompt context (redacted)")

        max_blocks = agent_expect.get("max_memory_blocks")
        if max_blocks is not None and diagnostics.get("memory_blocks_selected", 0) > max_blocks:
            passed = False
            failures.append(
                f"memory blocks {diagnostics['memory_blocks_selected']} exceeds max {max_blocks}"
            )

        max_chars = agent_expect.get("max_context_chars")
        if max_chars is not None and diagnostics.get("context_chars", 0) > max_chars:
            passed = False
            failures.append(f"context chars {diagnostics['context_chars']} exceeds max {max_chars}")

    result = {
        "fixture_id": fixture_id,
        "agent_passed": passed,
        "agent_failures": failures,
        "agent_diagnostics": {
            "memory_blocks_selected": diagnostics.get("memory_blocks_selected", 0),
            "memory_blocks_available": diagnostics.get("memory_blocks_available", 0),
            "recent_turns_selected": diagnostics.get("recent_turns_selected", 0),
            "message_count": diagnostics.get("message_count", 0),
            "context_chars": diagnostics.get("context_chars", 0),
            "memory_receipts_available": diagnostics.get("memory_receipts_available", 0),
        },
    }

    return passed, result


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: agent_contract_test.py <contract.json> [fixture.yaml]")
        sys.exit(1)

    contract_path = sys.argv[1]
    fixture_path = sys.argv[2] if len(sys.argv) > 2 else None

    passed, result = run_agent_contract(contract_path, fixture_path)
    print(json.dumps(result, indent=2))

    if not passed:
        sys.exit(1)


if __name__ == "__main__":
    main()
