# ADR 001: Versão do Hive Metastore (3.1.3)

- **Status:** aceita
- **Data:** 2026-10-30

## Contexto

O Hive Metastore é o catálogo do lakehouse: Spark, dbt (via Thrift Server) e
Superset dependem dele para enxergar as mesmas tabelas Delta armazenadas no MinIO.

A primeira versão do stack usava a imagem `apache/hive:4.0.1`. O smoke test
(`make smoke-test`) mostrou que o Spark conseguia gravar Delta no MinIO e criar
bancos no catálogo, mas falhava ao registrar ou ler tabelas:

```
AnalysisException: org.apache.hadoop.hive.ql.metadata.HiveException:
Unable to fetch table players. Invalid method name: 'get_table'
```

Causa:

- O Spark 3.5 conversa com o Metastore por um cliente Hive embutido, versão
  **2.3.9** (`/opt/spark/jars/hive-metastore-2.3.9.jar`).
- O Hive **4.0** removeu da API Thrift chamadas antigas, como `get_table`, que
  esse cliente usa.
- O Spark 3.5 suporta clientes do Metastore (`spark.sql.hive.metastore.version`)
  só **até a 3.1.3**. Não existe, portanto, cliente oficialmente suportado que
  funcione com o Metastore 4.x.

## Decisão

Usar o **Hive Metastore 3.1.3** (`apache/hive:3.1.3`), mantendo o cliente
padrão do Spark (2.3.9), que é compatível com servidores 3.x.

A imagem customizada em `docker/hive-metastore/` ajusta três pontos da imagem oficial:

1. **Driver JDBC do Postgres:** o driver incluído (9.4) não suporta
   autenticação SCRAM, padrão do Postgres 16. Ele é substituído pelo 42.7.4.
2. **Conector S3A:** `hadoop-aws` 3.1.0 e `aws-java-sdk-bundle` 1.11.271,
   alinhados ao Hadoop 3.1.0 empacotado no Hive 3.1.3.
3. **Inicialização idempotente:** o entrypoint oficial do 3.1.3 roda
   `schematool -initSchema` em todo start e falha se o schema já existe. Um
   wrapper (`entrypoint.sh`) consulta o schema com `schematool -info` e, se ele
   já existir, define `IS_RESUME=true` para pular a inicialização.

## Alternativas consideradas

- **Manter o Hive 4.0.1 e configurar no Spark um cliente 3.1.3**
  (`spark.sql.hive.metastore.version=3.1.3` + `spark.sql.hive.metastore.jars`):
  essa combinação não tem suporte oficial, ainda depende de chamadas que o
  Hive 4 pode ter removido e exigiria baixar ou empacotar os JARs do Hive 3 na
  imagem do Spark. Foi descartada por ser frágil.
- **Trocar o Hive Metastore por outro catálogo** (Unity Catalog OSS, Nessie,
  Polaris): faz mais sentido com Iceberg ou exige integrações menos maduras com
  Delta + dbt-spark + Superset. Fica fora do escopo de um stack local simples.
- **Atualizar para Spark 4.x**: o dbt-spark e o ecossistema Delta usado no
  projeto foram planejados para Spark 3.5. Pode ser reavaliado no futuro.

## Consequências

- Spark, Thrift Server e dbt usam o cliente padrão do Spark, sem configuração extra.
- O Hive 3.1.3 é uma versão antiga, sem novas releases. Para um lakehouse local
  de portfólio isso é aceitável, porque o catálogo só guarda metadados.
- Tabelas Delta são registradas no formato específico do Spark (o Hive avisa:
  *"Couldn't find corresponding Hive SerDe for data source provider delta"*).
  Isso é esperado: só o Spark e os clientes que passam pelo Thrift Server do
  Spark leem essas tabelas, e não o Hive diretamente.
- A troca de versão exigiu recriar o volume `postgres-data`, porque o schema do
  catálogo do Hive 4 não pode ser rebaixado. Os dados no MinIO não foram afetados.
- Se o projeto migrar para Spark 4.x, esta decisão deve ser revista.
