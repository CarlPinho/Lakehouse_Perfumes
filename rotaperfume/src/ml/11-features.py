# Databricks notebook source
# COMMAND ----------
# MAGIC %md
# MAGIC # 11-features.py — Engenharia de Features para Modelo de Propensão Semanal
# MAGIC
# MAGIC Criação de 20 features agrupadas em RFM, Ritmo, CRM e Mix para predição de propensão de compra.
# MAGIC Gera duas tabelas:
# MAGIC - `gold.features_treino` (corte em 2026-08-01 com target `comprou_em_7d`)
# MAGIC - `gold.features_cliente` (corte em 2026-08-31 para score)

# COMMAND ----------
from pyspark.sql import SparkSession

spark = SparkSession.builder.getOrCreate()

try:
    catalog = dbutils.widgets.get("catalog")
except Exception:
    catalog = "lakehouse_rotaperfume"

print(f"Executando engenharia de features no catálogo: {catalog}")

# COMMAND ----------
def montar_features(referencia: str):
    """
    Calcula 20 features para todos os clientes ativos com base no histórico anterior à data de referência.
    Garante ausência de data leakage filtrando todas as fontes estritamente com data < referencia.
    """
    query = f"""
    WITH f AS (
      SELECT *
      FROM {catalog}.gold.fato_vendas
      WHERE data_pedido < '{referencia}'
    ),
    -- Grupo 1: RFM
    rfm AS (
      SELECT
        cliente_id,
        CAST(datediff(DATE'{referencia}', MAX(data_pedido)) AS DOUBLE) AS recencia_dias,
        CAST(COUNT(DISTINCT pedido_id) AS DOUBLE) AS frequencia_pedidos,
        CAST(SUM(receita) AS DOUBLE) AS valor_total,
        CAST(SUM(receita) / NULLIF(COUNT(DISTINCT pedido_id), 0) AS DOUBLE) AS ticket_medio,
        CAST(SUM(margem) AS DOUBLE) AS margem_total,
        CAST(SUM(margem) / NULLIF(SUM(receita), 0) AS DOUBLE) AS margem_percentual
      FROM f
      GROUP BY cliente_id
    ),
    -- Grupo 2: Ritmo
    datas_unicas AS (
      SELECT DISTINCT cliente_id, data_pedido
      FROM f
    ),
    gaps AS (
      SELECT
        cliente_id,
        data_pedido,
        datediff(data_pedido, lag(data_pedido) OVER (PARTITION BY cliente_id ORDER BY data_pedido)) AS gap
      FROM datas_unicas
    ),
    ritmo_stats AS (
      SELECT
        cliente_id,
        CAST(AVG(gap) AS DOUBLE) AS intervalo_medio_dias,
        CAST(stddev(gap) AS DOUBLE) AS desvio_intervalo_dias
      FROM gaps
      WHERE gap IS NOT NULL
      GROUP BY cliente_id
    ),
    pedidos_90d AS (
      SELECT
        cliente_id,
        CAST(COUNT(DISTINCT pedido_id) AS DOUBLE) AS pedidos_ultimos_90d
      FROM f
      WHERE data_pedido >= date_sub(DATE'{referencia}', 90)
      GROUP BY cliente_id
    ),
    -- Grupo 3: CRM
    oportunidades_corte AS (
      SELECT
        cliente_id,
        CAST(COUNT(CASE WHEN NOT ganha AND NOT perdida THEN 1 END) AS DOUBLE) AS oportunidades_abertas,
        CAST(COUNT(CASE WHEN ganha THEN 1 END) AS DOUBLE) AS oportunidades_ganhas,
        CAST(COUNT(CASE WHEN ganha THEN 1 END) * 1.0 / NULLIF(COUNT(*), 0) AS DOUBLE) AS taxa_ganho
      FROM {catalog}.silver.oportunidades
      WHERE data_abertura < '{referencia}'
      GROUP BY cliente_id
    ),
    visitas_corte AS (
      SELECT
        cliente_id,
        CAST(COUNT(CASE WHEN data_visita >= date_sub(DATE'{referencia}', 90) THEN 1 END) AS DOUBLE) AS visitas_90d,
        CAST(COUNT(CASE WHEN resultado = 'Pedido realizado' THEN 1 END) * 1.0 / NULLIF(COUNT(*), 0) AS DOUBLE) AS conversao_visita
      FROM {catalog}.silver.visitas
      WHERE data_visita < '{referencia}'
      GROUP BY cliente_id
    ),
    -- Grupo 4: Mix
    mix_base AS (
      SELECT
        cliente_id,
        CAST(COUNT(DISTINCT sku) AS DOUBLE) AS skus_distintos,
        CAST(COUNT(DISTINCT categoria) AS DOUBLE) AS categorias_distintas,
        CAST(COUNT(DISTINCT marca) AS DOUBLE) AS marcas_distintas
      FROM f
      GROUP BY cliente_id
    ),
    marcas_rec AS (
      SELECT cliente_id, marca, SUM(receita) AS receita_marca
      FROM f
      GROUP BY cliente_id, marca
    ),
    marcas_top AS (
      SELECT
        cliente_id,
        CAST(MAX(receita_marca) AS DOUBLE) AS max_receita_marca
      FROM marcas_rec
      GROUP BY cliente_id
    ),
    lancamentos AS (
      SELECT DISTINCT f.cliente_id
      FROM f
      JOIN {catalog}.gold.dim_produto p ON f.sku = p.sku
      WHERE p.data_lancamento >= date_sub(DATE'{referencia}', 120)
        AND p.data_lancamento < DATE'{referencia}'
    )
    SELECT
      DATE'{referencia}' AS _referencia,
      r.cliente_id,
      -- RFM
      r.recencia_dias,
      r.frequencia_pedidos,
      r.valor_total,
      r.ticket_medio,
      r.margem_total,
      r.margem_percentual,
      -- Ritmo
      rs.intervalo_medio_dias,
      rs.desvio_intervalo_dias,
      CASE
        WHEN rs.intervalo_medio_dias IS NOT NULL AND rs.intervalo_medio_dias > 0
        THEN least(10.0, r.recencia_dias / rs.intervalo_medio_dias)
        ELSE NULL
      END AS atraso_relativo,
      coalesce(p90.pedidos_ultimos_90d, 0.0) AS pedidos_ultimos_90d,
      -- CRM
      coalesce(op.oportunidades_abertas, 0.0) AS oportunidades_abertas,
      coalesce(op.oportunidades_ganhas, 0.0) AS oportunidades_ganhas,
      coalesce(op.taxa_ganho, 0.0) AS taxa_ganho,
      coalesce(vi.visitas_90d, 0.0) AS visitas_90d,
      coalesce(vi.conversao_visita, 0.0) AS conversao_visita,
      -- Mix
      m.skus_distintos,
      m.categorias_distintas,
      m.marcas_distintas,
      CAST(coalesce(mt.max_receita_marca, 0.0) / NULLIF(r.valor_total, 0.0) AS DOUBLE) AS concentracao_marca_top,
      CASE WHEN l.cliente_id IS NOT NULL THEN 1.0 ELSE 0.0 END AS comprou_lancamento
    FROM rfm r
    LEFT JOIN ritmo_stats rs ON r.cliente_id = rs.cliente_id
    LEFT JOIN pedidos_90d p90 ON r.cliente_id = p90.cliente_id
    LEFT JOIN oportunidades_corte op ON r.cliente_id = op.cliente_id
    LEFT JOIN visitas_corte vi ON r.cliente_id = vi.cliente_id
    LEFT JOIN mix_base m ON r.cliente_id = m.cliente_id
    LEFT JOIN marcas_top mt ON r.cliente_id = mt.cliente_id
    LEFT JOIN lancamentos l ON r.cliente_id = l.cliente_id
    """
    return spark.sql(query)

# COMMAND ----------
# 1. Gerar features de treino (corte em 2026-08-01) com alvo comprou_em_7d
print("Gerando gold.features_treino com corte em 2026-08-01...")
df_treino_features = montar_features("2026-08-01")

df_alvo = spark.sql(f"""
    SELECT DISTINCT cliente_id, 1.0 AS comprou_em_7d
    FROM {catalog}.gold.fato_vendas
    WHERE data_pedido >= '2026-08-01' AND data_pedido <= '2026-08-07'
""")

df_treino = df_treino_features.join(df_alvo, on="cliente_id", how="left") \
    .fillna({"comprou_em_7d": 0.0})


df_treino.write.format("delta").mode("overwrite").saveAsTable(f"{catalog}.gold.features_treino")
spark.sql(f"COMMENT ON TABLE {catalog}.gold.features_treino IS 'Tabela de features de treino para propensao semanal com corte em 2026-08-01 e alvo de 7 dias'")

total_treino = spark.table(f"{catalog}.gold.features_treino").count()
print(f"gold.features_treino criada com sucesso: {total_treino} clientes.")

# COMMAND ----------
# 2. Gerar features de score (corte em 2026-08-31) sem alvo
print("Gerando gold.features_cliente com corte em 2026-08-31...")
df_score = montar_features("2026-08-31")

df_score.write.format("delta").mode("overwrite").saveAsTable(f"{catalog}.gold.features_cliente")
spark.sql(f"COMMENT ON TABLE {catalog}.gold.features_cliente IS 'Tabela de features de clientes para inferencia semanal com corte em 2026-08-31'")

total_score = spark.table(f"{catalog}.gold.features_cliente").count()
print(f"gold.features_cliente criada com sucesso: {total_score} clientes.")
