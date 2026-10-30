# CLAUDE.md — triple-double (projeto de portfólio)

Este arquivo dá contexto ao Claude Code sobre o projeto. Leia antes de qualquer tarefa.

**Nome:** `triple-double`, um trocadilho com as três camadas do medalhão (bronze, silver, gold). Repositório: `triple-double`. Pacote Python: `triple_double`.

## Visão geral

Pipeline de dados completo, de ponta a ponta, com dados de basquete da NBA, construído como projeto de portfólio de engenharia de dados.

- **Arquitetura medalhão** (bronze → silver → gold) em um lakehouse local
- **Duas fontes**: Basketball Reference (scraping) e NBA.com (via `nba_api`)
- **Orquestração** com Airflow
- **Modelagem dimensional** (star schema) na gold
- **Dataviz** com Superset
- Tudo roda localmente com `docker compose`, usando apenas software free/open source

O projeto deve ser **legível, reproduzível e bem documentado**: qualidade de código e clareza das decisões importam tanto quanto funcionar.

## Ambiente de desenvolvimento

- Windows 11 + **WSL2** (Ubuntu). O repositório vive dentro do filesystem do WSL (`~/projects/...`), nunca em `/mnt/c/...` (I/O lento e problemas de permissão).
- Docker Desktop com backend WSL2
- Hardware: Ryzen 7 5700X (8 cores), 32 GB RAM. Limite o Docker a ~20 GB no `.wslconfig`.
- Python 3.11 local, gerenciado com **uv** (venv para lint, testes e scripts de desenvolvimento)
- Java/Spark **não** são instalados localmente: rodam em container
- VS Code com extensões: Python, Jupyter, Docker, dbt Power User, Ruff

## Stack

| Camada | Ferramenta |
|---|---|
| Object storage | MinIO (compatível com S3) |
| Formato de tabela | Delta Lake |
| Catálogo | Hive Metastore 3.1.3 (backend Postgres). Não usar 4.x: o Spark 3.5 não é compatível com o Metastore 4 (ver `docs/adr/001-hive-metastore-version.md`) |
| Processamento | PySpark 3.5 (Spark master + worker + Thrift Server) |
| Transformação silver → gold | dbt (`dbt-spark`, conexão via Thrift) |
| Orquestração | Apache Airflow |
| Qualidade de dados | testes do dbt + Great Expectations |
| Dataviz | Apache Superset (conecta no Spark Thrift Server) |
| Lint/format | Ruff |
| Testes | pytest |
| CI | GitHub Actions |

## Estrutura do repositório

```
.
├── CLAUDE.md
├── README.md
├── Makefile
├── docker-compose.yml
├── .env.example                # nunca commitar .env
├── pyproject.toml              # uv + ruff + pytest
├── docker/                     # Dockerfiles e configs por serviço
│   ├── spark/
│   ├── airflow/
│   ├── hive-metastore/
│   └── superset/
├── src/triple_double/
│   ├── ingestion/
│   │   ├── bref/               # scraping Basketball Reference
│   │   ├── nba_api/            # extração via nba_api
│   │   └── common/             # rate limiter, http client, escrita na bronze
│   ├── bronze_to_silver/       # jobs PySpark
│   └── utils/
├── dbt/                        # projeto dbt (silver → gold)
│   ├── models/
│   │   ├── staging/
│   │   ├── intermediate/
│   │   └── marts/
│   └── tests/
├── airflow/dags/
├── tests/                      # pytest (unitários com fixtures de HTML/JSON)
├── notebooks/                  # exploração apenas; nada de lógica de produção aqui
└── docs/                       # diagramas, decisões (ADRs), screenshots
```

## Fontes de dados e regras de ingestão

### Basketball Reference (scraping)

- **Não existe API.** Ingestão via `requests` + `BeautifulSoup` / `pandas.read_html`.
- **Rate limit obrigatório:** a Sports Reference bloqueia acima de 20 requisições/minuto, com bloqueio de até um dia. Usar **no máximo 1 requisição a cada 4–6 segundos**, de forma **sequencial**: nunca paralelizar requisições ao site.
- Todo acesso passa por um único cliente HTTP com rate limiter central (`ingestion/common`), com retry e backoff exponencial para HTTP 429/5xx.
- Enviar um `User-Agent` identificável.
- Algumas tabelas vêm **dentro de comentários HTML** (`<!-- ... -->`): extrair os comentários antes de parsear.
- **Bronze guarda o HTML bruto**, não a tabela parseada. O parsing acontece na silver, o que permite reprocessar sem bater no site de novo.
- Usado para: **backfill histórico** (totais e advanced stats por temporada, prêmios, draft).

### NBA.com (`nba_api`)

- APIs não documentadas e sujeitas a mudanças: tratar erros, timeouts e headers com cuidado.
- Aplicar rate limiting conservador também aqui.
- Bronze guarda o **JSON bruto** da resposta.
- Usado para: **carga incremental diária** (jogos, box scores, play-by-play).

### Regras gerais

- **Nunca commitar dados** (HTML, JSON, Parquet, Delta) no repositório. Apenas código. Pequenas fixtures sintéticas ou mínimas para testes em `tests/fixtures/` são permitidas.
- Ingestão deve ser **idempotente**: reexecutar a mesma partição não duplica dados.

## Arquitetura medalhão

### Bronze
- Dado cru, sem transformação
- Caminho: `s3a://bronze/<fonte>/<entidade>/ingestion_date=YYYY-MM-DD/`
- Metadados obrigatórios: `source`, `url` ou `endpoint`, `ingested_at` (UTC), `content_hash`

### Silver (PySpark)
- Dados tipados, limpos, deduplicados, em Delta
- Padronizar nomes de colunas em `snake_case`, temporadas como `season_start_year` (ex.: 2025 para a temporada 2025-26)
- Tratar acentos e caracteres especiais nos nomes de jogadores
- Tratar jogadores trocados no meio da temporada (linhas `TOT` do Basketball Reference): manter as linhas por time e identificar a linha agregada com flag
- Escritas com `MERGE` (upsert) por chave natural

### Gold (dbt) — star schema
- **Fatos:** `fact_player_game`, `fact_player_season`, `fact_team_game`
- **Dimensões:** `dim_player`, `dim_team` (**SCD Tipo 2**, para mudanças de franquia, ex.: Seattle → OKC), `dim_season`, `dim_date`, `dim_game`
- **Mapeamento de IDs:** cada fonte tem seu ID de jogador (BR: `jokicni01`; NBA: `203999`). Manter uma tabela `map_player_ids` e uma `dim_player` conformada com surrogate key. Esse é um ponto central do projeto: documentar a estratégia de matching.

## Orquestração (Airflow)

- `dag_bref_backfill`: backfill histórico parametrizado por temporada; lento por design por causa do rate limit
- `dag_nba_daily`: incremental diário (jogos do dia anterior), seguido de silver → gold → testes
- DAGs finas: a lógica fica em `src/`, a DAG apenas orquestra
- Tasks idempotentes, com retries configurados

## Convenções de código

- Código, nomes de variáveis, funções, tabelas e colunas em **inglês**
- Comentários e documentação (README, docs/) em **português**
- Type hints em todo código Python; docstrings em funções públicas
- Ruff para lint e format (rodar antes de qualquer commit)
- Funções de parsing devem ser **puras** e testáveis com fixtures de HTML/JSON salvas em `tests/fixtures/`
- Configuração via variáveis de ambiente (`.env`), nunca hardcoded; segredos fora do Git
- Commits pequenos, mensagens no padrão Conventional Commits (`feat:`, `fix:`, `docs:`...)

## Comandos (a criar no Makefile)

```
make up          # sobe todo o stack
make down        # derruba o stack
make lint        # ruff check + format
make test        # pytest
make dbt-build   # dbt build (modelos + testes)
```

## O que NÃO fazer

- Não fazer requisições paralelas ao Basketball Reference nem remover o rate limiter
- Não commitar dados nem `.env`
- Não colocar lógica de transformação dentro das DAGs ou dos notebooks
- Não pular a bronze (sempre persistir o dado cru antes de transformar)

## Decisões em aberto

- Recorte temporal do histórico (era moderna, ex.: 2000+, ou todo o histórico)
- Idioma do README final (PT, EN ou bilíngue)
- Great Expectations vs. Soda para qualidade de dados
