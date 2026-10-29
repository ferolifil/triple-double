# MinIO compilado a partir do código-fonte.
#
# Em 2025 o MinIO deixou de publicar binários e imagens Docker da edição
# community (as imagens minio/minio e quay.io/minio/minio não estão mais
# acessíveis). O código continua aberto (AGPLv3), então compilamos aqui o
# servidor e o cliente `mc` em versões fixadas, o que mantém o build
# reproduzível.
#
# Observação: nas releases recentes o console web traz apenas o navegador de
# objetos (buckets e arquivos); a administração é feita pelo `mc admin`.

ARG MINIO_RELEASE=RELEASE.2025-10-15T17-29-55Z
ARG MC_RELEASE=RELEASE.2025-08-13T08-35-41Z

# --- Estágio de build ---------------------------------------------------------
FROM golang:1.24-alpine AS build
ARG MINIO_RELEASE
ARG MC_RELEASE

RUN apk add --no-cache git
ENV CGO_ENABLED=0

RUN git clone --depth 1 --branch ${MINIO_RELEASE} https://github.com/minio/minio.git /src/minio \
    && cd /src/minio && go build -trimpath -ldflags "-s -w" -o /out/minio .

RUN git clone --depth 1 --branch ${MC_RELEASE} https://github.com/minio/mc.git /src/mc \
    && cd /src/mc && go build -trimpath -ldflags "-s -w" -o /out/mc .

# --- Imagem final -------------------------------------------------------------
FROM alpine:3.20
RUN apk add --no-cache ca-certificates curl
COPY --from=build /out/minio /out/mc /usr/local/bin/

EXPOSE 9000 9001
ENTRYPOINT ["minio"]
