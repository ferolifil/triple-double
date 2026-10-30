#!/bin/bash
# Torna o start do metastore idempotente.
#
# O /entrypoint.sh oficial do Hive 3.1.3 roda `schematool -initSchema` sempre,
# a menos que IS_RESUME=true. Aqui consultamos o schema primeiro: se ele já
# existe no Postgres, o entrypoint oficial segue direto para o serviço.
set -euo pipefail

# A conexão JDBC chega via SERVICE_OPTS (propriedades -D definidas no compose)
if HADOOP_CLIENT_OPTS="${SERVICE_OPTS:-}" \
    "${HIVE_HOME}/bin/schematool" -dbType "${DB_DRIVER}" -info >/dev/null 2>&1; then
  echo "Schema do metastore já existe; pulando a inicialização."
  export IS_RESUME=true
fi

exec /entrypoint.sh
