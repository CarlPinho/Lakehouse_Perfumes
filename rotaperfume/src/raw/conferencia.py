# Databricks notebook source
# DBTITLE 1,Conferência de Chegada dos Arquivos Raw
"""
Notebook: conferencia.py
Objetivo: Validação de integridade e auditoria de chegada dos arquivos brutos (ERP e CRM)
          no Volume do Unity Catalog (/Volumes/{catalog}/bronze/raw/).

Responsabilidades:
1. Obter parâmetro 'catalog' via dbutils.widgets.
2. Inspecionar a existência e integridade dos 10 arquivos CSV esperados.
3. Obter tamanho em bytes e contagem exata de linhas de dados (excluindo header).
4. Interromper com exceção se algum arquivo estiver ausente ou vazio.
5. Gravar/atualizar a tabela de controle e auditoria bronze._raw_arquivos.
6. Exibir resumo estruturado e legível.
"""

from datetime import datetime, timezone
import os
from pyspark.sql import functions as F
from pyspark.sql.types import (
    StructType,
    StructField,
    StringType,
    LongType,
    TimestampType
)

# COMMAND ----------
# DBTITLE 1,Parâmetros de Execução
dbutils.widgets.text("catalog", "lakehouse_rotaperfume", "Nome do Catálogo")
catalog = dbutils.widgets.get("catalog")

print(f"==> Iniciando conferência de chegada no catálogo: {catalog}")

# COMMAND ----------
# DBTITLE 1,Mapeamento dos Arquivos Esperados
ARQUIVOS_ESPERADOS = {
    "erp": [
        "produtos.csv",
        "pedidos.csv",
        "itens_pedido.csv",
        "pagamentos.csv",
        "estoque.csv"
    ],
    "crm": [
        "clientes.csv",
        "vendedores.csv",
        "carteira.csv",
        "oportunidades.csv",
        "visitas.csv"
    ]
}

# COMMAND ----------
# DBTITLE 1,Inspeção e Validação dos Arquivos no Volume
conferido_em = datetime.now(timezone.utc)
relatorio = []
erros = []

for sistema, lista_arquivos in ARQUIVOS_ESPERADOS.items():
    volume_dir = f"/Volumes/{catalog}/bronze/raw/{sistema}"
    
    for nome_arquivo in lista_arquivos:
        caminho_arquivo = f"{volume_dir}/{nome_arquivo}"
        
        # 1. Verificar existência e obter tamanho em bytes
        tamanho_bytes = 0
        existe = False
        
        try:
            if os.path.exists(caminho_arquivo):
                existe = True
                tamanho_bytes = os.path.getsize(caminho_arquivo)
            else:
                # Fallback via dbutils.fs caso os.path não monte diretamente
                info = dbutils.fs.ls(caminho_arquivo)
                if len(info) > 0:
                    existe = True
                    tamanho_bytes = info[0].size
        except Exception as e:
            erros.append(f"Erro ao acessar {caminho_arquivo}: {str(e)}")
            continue

        if not existe:
            erros.append(f"Arquivo ausente: {caminho_arquivo}")
            continue

        if tamanho_bytes == 0:
            erros.append(f"Arquivo vazio (0 bytes): {caminho_arquivo}")
            continue

        # 2. Contar linhas de dados (total de linhas do arquivo menos o cabeçalho)
        try:
            total_linhas = spark.read.text(caminho_arquivo).count()
            linhas_dados = max(0, total_linhas - 1)
        except Exception as e:
            erros.append(f"Falha ao ler linhas de {caminho_arquivo}: {str(e)}")
            continue

        if linhas_dados == 0:
            erros.append(f"Arquivo sem linhas de dados (apenas cabeçalho ou vazio): {caminho_arquivo}")
            continue

        relatorio.append((sistema, nome_arquivo, int(tamanho_bytes), int(linhas_dados), conferido_em))

# COMMAND ----------
# DBTITLE 1,Verificação de Erros
if erros:
    print("=" * 80)
    print("❌ FALHA NA CONFERÊNCIA DE CHEGADA - PIPELINE INTERROMPIDO")
    print("=" * 80)
    for erro in erros:
        print(f"  - {erro}")
    raise RuntimeError(f"Conferência de chegada falhou com {len(erros)} erro(s). Verifique os logs acima.")

# COMMAND ----------
# DBTITLE 1,Gravação da Tabela de Controle bronze._raw_arquivos
schema_controle = StructType([
    StructField("sistema", StringType(), False),
    StructField("arquivo", StringType(), False),
    StructField("bytes", LongType(), False),
    StructField("linhas", LongType(), False),
    StructField("conferido_em", TimestampType(), False)
])

df_controle = spark.createDataFrame(relatorio, schema=schema_controle)

# Salvar tabela de auditoria Delta
tabela_destino = f"{catalog}.bronze._raw_arquivos"
df_controle.write.format("delta") \
    .mode("overwrite") \
    .option("overwriteSchema", "true") \
    .saveAsTable(tabela_destino)

# Aplicar comentários de documentação no catálogo
spark.sql(f"COMMENT ON TABLE {tabela_destino} IS 'Tabela de auditoria e conferência de chegada dos arquivos na camada Raw (Volume)'")

# COMMAND ----------
# DBTITLE 1,Exibição do Relatório de Chegada
print("\n" + "=" * 80)
print("✅ CONFERÊNCIA DE CHEGADA CONCLUÍDA COM SUCESSO")
print("=" * 80)

display(spark.table(tabela_destino).orderBy(F.col("linhas").desc()))
