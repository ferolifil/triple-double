"""Smoke test do lakehouse: Spark + Delta Lake + MinIO (S3A) + Hive Metastore.

Roda dentro do container spark-master via spark-submit (ver `make smoke-test`):

1. cria um DataFrame pequeno;
2. grava como tabela Delta em s3a://bronze/smoke_test/;
3. registra a tabela no Hive Metastore (smoke_test.players);
4. lê de volta com Spark SQL e imprime o resultado.

É idempotente: reexecutar sobrescreve os dados e reaproveita o registro no catálogo.
As configurações (Delta, S3A, Metastore) vêm do spark-defaults.conf da imagem.
"""

import sys

from pyspark.sql import SparkSession

DATABASE = "smoke_test"
TABLE = f"{DATABASE}.players"
LOCATION = "s3a://bronze/smoke_test/"

ROWS = [
    ("jokicni01", "Nikola Jokić", "DEN", 2024, 29.6),
    ("gilgesh01", "Shai Gilgeous-Alexander", "OKC", 2024, 32.7),
    ("doncilu01", "Luka Dončić", "DAL", 2024, 28.2),
]
SCHEMA = "player_id STRING, player_name STRING, team STRING, season_start_year INT, pts_per_game DOUBLE"


def main() -> int:
    """Executa o smoke test e retorna o exit code (0 = sucesso)."""
    spark = SparkSession.builder.appName("triple-double-smoke-test").getOrCreate()
    spark.sparkContext.setLogLevel("WARN")

    try:
        df = spark.createDataFrame(ROWS, schema=SCHEMA)

        # Escrita direta no caminho (sem passar pelo catálogo), como fará a ingestão
        df.write.format("delta").mode("overwrite").save(LOCATION)

        # Registro como tabela externa: o Metastore guarda só o schema e a localização
        spark.sql(f"CREATE DATABASE IF NOT EXISTS {DATABASE}")
        spark.sql(f"CREATE TABLE IF NOT EXISTS {TABLE} USING DELTA LOCATION '{LOCATION}'")

        result = spark.sql(
            f"SELECT player_id, player_name, team, season_start_year, pts_per_game "
            f"FROM {TABLE} ORDER BY pts_per_game DESC"
        )
        result.show(truncate=False)
        spark.sql(f"DESCRIBE DETAIL {TABLE}").select("format", "location", "numFiles").show(
            truncate=False
        )

        count = result.count()
        if count != len(ROWS):
            print(f"SMOKE TEST FALHOU: esperadas {len(ROWS)} linhas, lidas {count}")
            return 1

        print(f"SMOKE TEST OK: {count} linhas gravadas e lidas de {TABLE} ({LOCATION})")
        return 0
    finally:
        spark.stop()


if __name__ == "__main__":
    sys.exit(main())
