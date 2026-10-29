# Hive Metastore standalone, a partir da imagem oficial do Apache Hive.
#
# A imagem oficial não traz:
#   - o driver JDBC do Postgres (backend do catálogo);
#   - o conector S3A (hadoop-aws + AWS SDK), necessário porque o metastore
#     cria os diretórios de bancos e tabelas no MinIO (s3a://...).
# Os JARs são baixados no build e colocados no classpath do Hive.
FROM apache/hive:4.0.1

# Versões alinhadas ao Hadoop 3.3.6 empacotado no Hive 4.0.1
ARG POSTGRES_JDBC_VERSION=42.7.4
ARG HADOOP_AWS_VERSION=3.3.6
ARG AWS_SDK_BUNDLE_VERSION=1.12.367

ADD --chmod=644 \
    https://repo1.maven.org/maven2/org/postgresql/postgresql/${POSTGRES_JDBC_VERSION}/postgresql-${POSTGRES_JDBC_VERSION}.jar \
    https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/${HADOOP_AWS_VERSION}/hadoop-aws-${HADOOP_AWS_VERSION}.jar \
    https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/${AWS_SDK_BUNDLE_VERSION}/aws-java-sdk-bundle-${AWS_SDK_BUNDLE_VERSION}.jar \
    /opt/hive/lib/

# Configurações customizadas (hive-site.xml e core-site.xml). O entrypoint da
# imagem oficial copia os arquivos de HIVE_CUSTOM_CONF_DIR para o conf do Hive.
COPY conf/ /hive_custom_conf/
ENV HIVE_CUSTOM_CONF_DIR=/hive_custom_conf
