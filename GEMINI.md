# Lakehouse Perfumes - Contexto e Diretrizes do Projeto

Este arquivo define os padrões de desenvolvimento, arquitetura e comandos para agentes de IA e desenvolvedores no projeto **Lakehouse_Perfumes**.

---

## 1. Visão Geral e Arquitetura

Projeto de Engenharia de Dados com arquitetura **Lakehouse Medallion (Bronze -> Silver -> Gold)**, gerenciado e implantado via **Databricks Asset Bundles (DABs)**.

* **Stack Tecnológica:**
  * Python (>=3.10, <3.13)
  * PySpark / Databricks Connect 15.4+ / Delta Live Tables (DLT)
  * Databricks CLI (v0.200+) & DABs
  * Pytest / Ruff (Linter & Formatter)
* **Workspace Databricks:** `https://dbc-3914c6d4-fd43.cloud.databricks.com`
* **Catálogo Unity Catalog:** `lakehouse_rotaperfume`
  * Ambiente `dev` (padrão): schema `dev`
  * Ambiente `prod`: schema `prod`

---

## 2. Estrutura do Repositório

```text
Lakehouse_Perfumes/
├── dados/                       # Dados brutos / arquivos locais de entrada
├── rotaperfume/                 # Projeto Databricks Asset Bundle (DAB)
│   ├── databricks.yml           # Configuração do Bundle e targets (dev / prod)
│   ├── pyproject.toml           # Dependências Python e configurações do Ruff
│   ├── resources/               # Definições de Jobs, Pipelines DLT e recursos Databricks em YAML
│   ├── src/                     # Código fonte das transformações PySpark / DLT
│   ├── tests/                   # Testes unitários com Pytest
│   └── fixtures/                # Dados mockados para testes locais
├── GEMINI.md                    # Instruções de contexto para Gemini / Antigravity
└── AGENTS.md                    # Instruções de contexto para agentes de IA
```

---

## 3. Comandos Úteis

Execute os comandos a partir do diretório `rotaperfume/`:

### Databricks Asset Bundles (DABs)
```bash
# Validar sintaxe e integridade do bundle
databricks bundle validate

# Fazer deploy no ambiente de desenvolvimento (dev)
databricks bundle deploy -t dev

# Executar job ou pipeline no Databricks
databricks bundle run -t dev

# Fazer deploy no ambiente de produção
databricks bundle deploy -t prod
```

### Qualidade de Código & Testes
```bash
# Executar linters e formatadores
ruff check .
ruff format .

# Executar bateria de testes unitários
pytest
```

---

## 4. Padrões de Código e Boas Práticas

### Convenções de Nomenclatura
* **Tabelas, Colunas, Variáveis e Funções:** `snake_case` (ex.: `id_cliente`, `data_venda`, `calcular_total`).
* **Classes:** `PascalCase`.
* **Arquivos e Módulos:** `snake_case.py`.

### Arquitetura Medallion
1. **Bronze (`bronze_*`):**
   * Armazenar os dados brutos como recebidos da fonte (Raw / Append-only).
   * Adicionar metadados de ingestão: `_ingestion_timestamp` e `_source_file`.
2. **Silver (`silver_*`):**
   * Limpeza de dados, tipagem estrita de colunas, deduplicação e normalização.
   * Tratamento de nulos e aplicação de regras de qualidade de dados.
3. **Gold (`gold_*`):**
   * Agregações de negócio, dimensões, fatos e data marts otimizados para consumo analítico e BI.

### Engenharia de Dados & PySpark
* Priorizar funções nativas do `pyspark.sql.functions` em vez de UDFs Python puras (para garantir otimização pelo Catalyst Optimizer).
* Sempre explicitar schemas ao carregar arquivos semiestruturados (JSON, CSV).
* Usar Delta Lake como formato padrão com propriedades como `optimizeWrite` e `autoCompact` quando aplicável.
