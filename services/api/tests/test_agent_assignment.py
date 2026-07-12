from app.agent_assignment import agent_cancel_url


def test_agent_cancel_url_replaces_endpoint_suffix_without_trimming_port() -> None:
    assert (
        agent_cancel_url("http://realtime-agent:8001/v1/agent/assign")
        == "http://realtime-agent:8001/v1/agent/cancel"
    )


def test_agent_cancel_url_preserves_base_path() -> None:
    assert (
        agent_cancel_url("https://example.test/companion/v1/agent/assign")
        == "https://example.test/companion/v1/agent/cancel"
    )
