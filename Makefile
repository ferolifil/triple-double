# Atalhos do projeto. Rode `make help` para listar os alvos.

.DEFAULT_GOAL := help
.PHONY: help up down check-env smoke-test

help: ## Lista os alvos disponíveis
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

check-env: # Garante que o .env existe antes de subir o stack
	@test -f .env || (echo "Arquivo .env não encontrado. Rode: cp .env.example .env" && exit 1)

up: check-env ## Sobe todo o stack (builda as imagens se necessário)
	docker compose up -d --build

down: ## Derruba o stack (mantém os volumes com dados)
	docker compose down

# O script é copiado para o container (não há volume montado para scripts/).
# spark.driver.host: o driver roda no spark-master e os executors no worker
# precisam alcançá-lo pelo nome do serviço na rede do compose.
smoke-test: ## Valida Spark + Delta + MinIO + Hive Metastore (stack precisa estar de pé)
	docker compose cp scripts/smoke_test.py spark-master:/tmp/smoke_test.py
	docker compose exec spark-master /opt/spark/bin/spark-submit \
		--master spark://spark-master:7077 \
		--conf spark.driver.host=spark-master \
		/tmp/smoke_test.py
