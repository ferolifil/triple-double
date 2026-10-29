# Atalhos do projeto. Rode `make help` para listar os alvos.

.DEFAULT_GOAL := help
.PHONY: help up down check-env

help: ## Lista os alvos disponíveis
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

check-env: # Garante que o .env existe antes de subir o stack
	@test -f .env || (echo "Arquivo .env não encontrado. Rode: cp .env.example .env" && exit 1)

up: check-env ## Sobe todo o stack (builda as imagens se necessário)
	docker compose up -d --build

down: ## Derruba o stack (mantém os volumes com dados)
	docker compose down
