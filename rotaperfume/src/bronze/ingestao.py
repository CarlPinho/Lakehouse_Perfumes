# Databricks notebook source
# DBTITLE 1,Ingestão da Camada Bronze (Raw -> Delta)
"""
Notebook: ingestao.py
Objetivo: Leitura dos 10 arquivos CSV brutos no Volume do Unity Catalog
          e gravação nas respectivas tabelas Delta da camada Bronze.

Regras da Camada Bronze:
1. Ingestão pura (Raw -> Bronze Delta) sem limpeza ou conversões de tipos.
2. Todas as colunas de negócio mantidas como STRING (inferSchema=False).
3. Adição de metadados técnicos de linhagem: _ingerido_em e _arquivo_origem.
4. Aplicação de comentários documentando a origem no Unity Catalog.
5. Conciliação automática: comparação de contagem de linhas contra bronze._raw_arquivos.
"""

from datetime import datetime, timezone
from pyspark.sql import functions as F

# COMMAND ----------
# DBTITLE 1,Parâmetros de Execução
dbutils.widgets.text("catalog", "lakehouse_rotaperfume", "Nome do Catálogo")
catalog = dbutils.widgets.get("catalog")

print(f"==> Iniciando ingestão da camada Bronze no catálogo: {catalog}")

# COMMAND ----------
# DBTITLE 1,Mapeamento das Entidades (ERP e CRM)
TABELAS_BRONZE = {
    "erp": [
        "produtos",
        "pedidos",
        "itens_pedido",
        "pagamentos",
        "estoque"
    ],
    "crm": [
        "clientes",
        "vendedores",
        "carteira",
        "oportunidades",
        "visitas"
    ]
}

# COMMAND ----------
# DBTITLE 1,Função Única de Ingestão para a Bronze
def ingerir_tabela_bronze(sistema: str, tabela: str, catalogo: str, timestamp_execucao: datetime) -> int:
    """
    Lê um arquivo CSV do Volume sem inferência de tipos e grava como tabela Delta na Bronze.
    """
    caminho_csv = f"/Volumes/{catalogo}/bronze/raw/{sistema}/{tabela}.csv"
    tabela_destino = f"{catalogo}.bronze.{tabela}"
    
    # 1. Leitura com preservação estrita de tipos (tudo string)
    df_raw = (
        spark.read
        .format("csv")
        .option("header", "true")
        .option("inferSchema", "false")
        .option("multiLine", "false")
        .load(caminho_csv)
    )
    
    # Caso a coluna _rescued_data seja injetada automaticamente pelo leitor, descarte
    if "_rescued_data" in df_raw.columns:
        df_raw = df_raw.drop("_rescued_data")
    
    # 2. Adição dos metadados técnicos
    df_bronze = (
        df_raw
        .withColumn("_ingerido_em", F.lit(timestamp_execucao).cast("timestamp"))
        .withColumn("_arquivo_origem", F.lit(f"{tabela}.csv"))
    )
    
    # 3. Gravação na tabela Delta com modo overwrite
    (
        df_bronze.write
        .format("delta")
        .mode("overwrite")
        .option("overwriteSchema", "true")
        .saveAsTable(tabela_destino)
    )
    
    # 4. Documentação no Unity Catalog
    comentario = f"Tabela Bronze {tabela} ingerida a partir de {sistema.upper()} ({tabela}.csv). Dados brutos preservados como texto."
    spark.sql(f"COMMENT ON TABLE {tabela_destino} IS '{comentario}'")
    
    total_linhas = df_bronze.count()
    return total_linhas

# COMMAND ----------
# DBTITLE 1,Execução da Ingestão em Loop
timestamp_execucao = datetime.now(timezone.utc)
resultado_ingestao = {}

print("=" * 80)
print("INICIANDO INGESTÃO DAS 10 TABELAS BRONZE")
print("=" * 80)

for sistema, tabelas in TABELAS_BRONZE.items():
    for tabela in tabelas:
        linhas = ingerir_tabela_bronze(sistema, tabela, catalog, timestamp_execucao)
        resultado_ingestao[tabela] = linhas
        print(f"  ✓ [{sistema.upper()}] {tabela}: {linhas:,} linhas gravadas em {catalog}.bronze.{tabela}")

# COMMAND ----------
# DBTITLE 1,Conciliação de Contagem com bronze._raw_arquivos
print("\n" + "=" * 80)
print("VALIDAÇÃO E CONCILIAÇÃO COM bronze._raw_arquivos")
print("=" * 80)

df_raw_controle = spark.table(f"{catalog}.bronze._raw_arquivos").select("arquivo", "linhas").collect()
controle_dict = {row["arquivo"]: row["linhas"] for row in df_raw_controle}

dados_conciliacao = []
divergencias = []

for tabela, linhas_tabela in resultado_ingestao.items():
    nome_arquivo = f"{tabela}.csv"
    linhas_arquivo = controle_dict.get(nome_arquivo, -1)
    bate = (linhas_tabela == linhas_arquivo)
    
    dados_conciliacao.append((tabela, int(linhas_tabela), int(linhas_arquivo), bool(bate)))
    
    if not bate:
        divergencias.append(
            f"Divergência em '{tabela}': tabela Delta tem {linhas_tabela} linhas, "
            f"mas o arquivo {nome_arquivo} registrou {linhas_arquivo} linhas."
        )

# Criar DataFrame para exibição limpa
df_conciliacao = spark.createDataFrame(
    dados_conciliacao,
    ["tabela", "linhas_na_tabela", "linhas_no_arquivo", "bate"]
)

display(df_conciliacao.orderBy(F.col("linhas_na_tabela").desc()))

if divergencias:
    print("\n❌ ERRO DE CONCILIAÇÃO:")
    for div in divergencias:
        print(f"  - {div}")
    raise RuntimeError(f"Ingestão da Bronze falhou com {len(divergencias)} divergência(s) de contagem.")

print(f"\n✅ SUCESSO: Todas as 10 tabelas Bronze conferidas e validadas ({sum(resultado_ingestao.values()):,} linhas no total).")
