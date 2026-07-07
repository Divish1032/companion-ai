# Contributing

Read `AGENTS.md` first. This repo is sprint-driven; keep work scoped to the active sprint unless the user explicitly changes scope.

## Before Starting

1. Read `docs/AGENT_CONTEXT.md`.
2. Read `docs/SPRINTS.md`.
3. Read only the architecture docs relevant to the active sprint.

## Commit Style

Use concise conventional-style commit subjects when possible:

```text
docs(sprint): add Sarvam streaming validation notes
infra(git): add repository hygiene files
mobile(chat): add voice chat shell
```

Each commit should explain:

- why the change exists
- what changed
- how it was verified

## Scope Rules

- Do not add auth unless explicitly requested.
- Do not add text chat UI or a text input box.
- Do not build video/avatar features in MVP tasks.
- Do not persist raw audio.
- Do not hard-code secrets or API keys.

