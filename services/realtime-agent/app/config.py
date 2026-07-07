import os
import tomllib
from pathlib import Path
from typing import Any

from app.providers import ProviderRouting


def _repo_root() -> Path:
    for parent in Path(__file__).resolve().parents:
        if (parent / "config" / "personas").is_dir():
            return parent
    return Path.cwd()


def load_toml(path: str | Path) -> dict[str, Any]:
    with Path(path).open("rb") as file:
        return tomllib.load(file)


def load_provider_routing() -> ProviderRouting:
    default_path = _repo_root() / "config" / "personas" / "hindi_companion_v1.toml"
    path = Path(os.getenv("AGENT_PERSONA_CONFIG", default_path))

    return ProviderRouting.from_dict(load_toml(path))
