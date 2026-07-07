.PHONY: setup dev check mobile logs

setup:
	cd apps/mobile && flutter pub get
	cd services/api && uv sync
	cd services/realtime-agent && uv sync

dev:
	docker compose -f infra/docker-compose.yml up --build

check:
	./scripts/verify-docs.sh
	./scripts/verify-sprint0.sh
	./scripts/check-python-service.sh services/api
	./scripts/check-python-service.sh services/realtime-agent
	./scripts/check-flutter.sh

mobile:
	cd apps/mobile && flutter run

logs:
	docker compose -f infra/docker-compose.yml logs -f
