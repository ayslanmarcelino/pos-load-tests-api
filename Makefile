.PHONY: setup up down seed test test-health test-slow test-fast test-ramp-slow test-ramp-fast

setup: ## Sobe os containers e prepara o banco (migrations + seed)
	docker compose up -d --build
	docker compose exec web bin/rails db:prepare
	docker compose exec web bin/rails db:seed

up: ## Sobe a aplicação (containers já buildados)
	docker compose up

down: ## Para os containers
	docker compose down

seed: ## Roda os seeds novamente
	docker compose exec web bin/rails db:seed

test: ## Roda a suíte de testes Rails
	bin/rails test

test-health: ## k6: baseline /health
	k6 run load_tests/health.js

test-slow: ## k6: /api/v1/users/slow (com N+1)
	k6 run load_tests/slow.js

test-fast: ## k6: /api/v1/users/fast (com includes)
	k6 run load_tests/fast.js

test-ramp-slow: ## k6: ramp test contra /slow
	ENDPOINT=/api/v1/users/slow k6 run load_tests/ramp.js

test-ramp-fast: ## k6: ramp test contra /fast
	ENDPOINT=/api/v1/users/fast k6 run load_tests/ramp.js
