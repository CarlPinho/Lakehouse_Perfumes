WITH fila_kpis AS (
  SELECT
    COUNT(*) AS contatos,
    COUNT(DISTINCT vendedor) AS vendedores,
    ROUND(SUM(score * ticket_medio), 2) AS receita_esperada,
    DATE'2026-08-31' AS referencia
  FROM lakehouse_rotaperfume.gold.fila_semanal
),
modelo_kpis AS (
  SELECT
    acertos_top200,
    ROUND(lift_top200, 2) AS lift_top200,
    ROUND(taxa_base, 4) AS taxa_base
  FROM lakehouse_rotaperfume.gold.modelo_metricas
  QUALIFY ROW_NUMBER() OVER (ORDER BY versao DESC) = 1
),
retorno_kpis AS (
  SELECT
    COUNT(*) AS ja_trabalhados,
    COUNT(CASE WHEN status = 'vendeu' THEN 1 END) AS viraram_pedido
  FROM lakehouse_rotaperfume.gold.retorno_ligacao
)
SELECT
  f.contatos,
  f.vendedores,
  f.receita_esperada,
  f.referencia,
  m.acertos_top200,
  m.lift_top200,
  m.taxa_base,
  r.ja_trabalhados,
  r.viraram_pedido
FROM fila_kpis f
CROSS JOIN modelo_kpis m
CROSS JOIN retorno_kpis r;
