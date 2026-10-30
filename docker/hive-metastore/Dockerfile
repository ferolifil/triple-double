# Hive Metastore standalone, a partir da imagem oficial do Apache Hive.
#
# Versão 3.1.3, e não 4.x: o Spark 3.5 só traz clientes do Metastore até a
# 3.1.3, e o Hive 4 removeu chamadas Thrift que esses clientes usam
# (ex.: get_table). Detalhes em docs/adr/001-hive-metastore-version.md.
#
# A imagem oficial não traz:
#   - um driver JDBC do Postgres recente (o 9.4 incluído não suporta a
#     autenticação SCRAM, padrão do Postgres 16);
#   - o conector S3A no classpath do Hive, necessário porque o metastore
#     cria os diretórios de bancos e tabelas no MinIO (s3a://...).
# Os JARs são baixados no build e colocados no classpath do Hive.
FROM apache/hive:3.1.3

# Versões alinhadas ao Hadoop 3.1.0 empacotado no Hive 3.1.3
ARG POSTGRES_JDBC_VERSION=42.7.4
ARG HADOOP_AWS_VERSION=3.1.0
ARG AWS_SDK_BUNDLE_VERSION=1.11.271

USER root

# Remove o driver antigo para não haver duas versões no classpath
RUN rm -f /opt/hive/lib/postgresql-9.4.*.jar

ADD --chmod=644 \
    https://repo1.maven.org/maven2/org/postgresql/postgresql/${POSTGRES_JDBC_VERSION}/postgresql-${POSTGRES_JDBC_VERSION}.jar \
    https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/${HADOOP_AWS_VERSION}/hadoop-aws-${HADOOP_AWS_VERSION}.jar \
    https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/${AWS_SDK_BUNDLE_VERSION}/aws-java-sdk-bundle-${AWS_SDK_BUNDLE_VERSION}.jar \
    /opt/hive/lib/

# Configurações customizadas (hive-site.xml e core-site.xml). O entrypoint da
# imagem oficial cria links dos arquivos de HIVE_CUSTOM_CONF_DIR no conf do Hive.
COPY conf/ /hive_custom_conf/
ENV HIVE_CUSTOM_CONF_DIR=/hive_custom_conf

# Wrapper do entrypoint: a imagem 3.1.3 roda `schematool -initSchema` em todo
# start (e falha se o schema já existe). O wrapper pula essa etapa quando o
# catálogo já foi inicializado no Postgres.
COPY --chmod=755 entrypoint.sh /usr/local/bin/metastore-entrypoint.sh

USER hive
ENTRYPOINT ["/usr/local/bin/metastore-entrypoint.sh"]
