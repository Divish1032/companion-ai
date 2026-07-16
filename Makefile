.PHONY: setup dev check mobile logs tts-kokoro-smoke tts-kokoro-benchmark tts-kokoro-previews tts-e2e-sarvam

setup:
	cd apps/mobile && flutter pub get
	cd services/api && uv sync
	cd services/realtime-agent && uv sync

dev:
	docker compose --env-file .env -f infra/docker-compose.yml up --build

check:
	./scripts/verify-docs.sh
	./scripts/verify-sprint0.sh
	./scripts/check-python-service.sh services/api
	./scripts/check-python-service.sh services/realtime-agent
	./scripts/check-flutter.sh

mobile:
	cd apps/mobile && flutter run

logs:
	docker compose --env-file .env -f infra/docker-compose.yml logs -f

tts-kokoro-smoke:
	./scripts/kokoro-smoke.sh

tts-kokoro-benchmark:
	./scripts/kokoro-benchmark.py

tts-kokoro-previews:
	./scripts/generate-kokoro-previews.py

tts-e2e-sarvam:
	./scripts/sarvam-fallback-e2e.sh
