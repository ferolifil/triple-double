# Imagem do Spark usada pelo master e pelo worker (e, nas próximas etapas,
# pelo Thrift Server). Parte da imagem oficial com Python e adiciona:
#   - Delta Lake (formato de tabela das camadas silver e gold);
#   - conector S3A (hadoop-aws + AWS SDK) para ler/escrever no MinIO.
# Os JARs ficam em /opt/spark/jars, então não é preciso usar --packages
# (que baixaria dependências a cada sessão).
FROM apache/spark:3.5.3-python3

# Spark 3.5 -> Delta 3.2.x; Hadoop 3.3.4 (empacotado no Spark) -> hadoop-aws 3.3.4
ARG DELTA_VERSION=3.2.1
ARG HADOOP_AWS_VERSION=3.3.4
ARG AWS_SDK_BUNDLE_VERSION=1.12.262

ADD --chmod=644 \
    https://repo1.maven.org/maven2/io/delta/delta-spark_2.12/${DELTA_VERSION}/delta-spark_2.12-${DELTA_VERSION}.jar \
    https://repo1.maven.org/maven2/io/delta/delta-storage/${DELTA_VERSION}/delta-storage-${DELTA_VERSION}.jar \
    https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/${HADOOP_AWS_VERSION}/hadoop-aws-${HADOOP_AWS_VERSION}.jar \
    https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/${AWS_SDK_BUNDLE_VERSION}/aws-java-sdk-bundle-${AWS_SDK_BUNDLE_VERSION}.jar \
    /opt/spark/jars/

COPY spark-defaults.conf /opt/spark/conf/spark-defaults.conf
