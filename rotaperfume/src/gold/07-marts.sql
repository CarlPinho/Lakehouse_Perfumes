-- ==============================================================================
-- 07-marts.sql: Criação dos Data Marts Especializados por Diretoria
-- ==============================================================================

-- 1. Mart de Vendas por Vendedor (Diretoria Comercial)
CREATE OR REPLACE TABLE lakehouse_rotaperfume.gold.mart_vendas_por_vendedor AS
SELECT
  f.vendedor_id,
  v.nome AS vendedor_nome,
  v.regiao,
  f.ano,
  f.mes,
  ROUND(SUM(f.receita), 2) AS receita,
  ROUND(SUM(f.margem), 2) AS margem,
  v.meta_mensal AS meta,
  ROUND(100.0 * SUM(f.receita) / NULLIF(v.meta_mensal, 0), 2) AS atingimento_pct,
  COUNT(DISTINCT f.cliente_id) AS clientes_atendidos,
  ROUND(SUM(f.receita) / COUNT(DISTINCT f.pedido_id), 2) AS ticket_medio
FROM lakehouse_rotaperfume.gold.fato_vendas f
LEFT JOIN lakehouse_rotaperfume.gold.dim_vendedor v ON f.vendedor_id = v.vendedor_id
GROUP BY f.vendedor_id, v.nome, v.regiao, f.ano, f.mes, v.meta_mensal;

COMMENT ON TABLE lakehouse_rotaperfume.gold.mart_vendas_por_vendedor IS 'Data Mart comercial consolidando desempenho de vendas, atingimento de metas e ticket médio por vendedor e mês';

-- 2. Mart de Performance de Produto (Diretoria de Produtos / Marketing)
CREATE OR REPLACE TABLE lakehouse_rotaperfume.gold.mart_produto_performance AS
WITH agregado AS (
  SELECT
    f.sku,
    f.categoria,
    f.marca,
    f.ano,
    f.mes,
    ROUND(SUM(f.receita), 2) AS receita,
    ROUND(SUM(f.margem), 2) AS margem,
    ROUND(100.0 * SUM(f.margem) / NULLIF(SUM(f.receita), 0), 2) AS margem_pct,
    SUM(f.quantidade) AS quantidade
  FROM lakehouse_rotaperfume.gold.fato_vendas f
  GROUP BY f.sku, f.categoria, f.marca, f.ano, f.mes
),
com_acumulado AS (
  SELECT
    *,
    SUM(receita) OVER (ORDER BY receita DESC) / NULLIF(SUM(receita) OVER (), 0) AS pct_acumulado
  FROM agregado
)
SELECT
  sku,
  categoria,
  marca,
  ano,
  mes,
  receita,
  margem,
  margem_pct,
  quantidade,
  CASE
    WHEN pct_acumulado <= 0.80 THEN 'A'
    WHEN pct_acumulado <= 0.95 THEN 'B'
    ELSE 'C'
  END AS curva_abc
FROM com_acumulado;

COMMENT ON TABLE lakehouse_rotaperfume.gold.mart_produto_performance IS 'Data Mart de performance de produtos com rentabilidade, volume físico e classificação em Curva ABC';

-- 3. Mart Financeiro de Recebimento (Diretoria Financeira)
CREATE OR REPLACE TABLE lakehouse_rotaperfume.gold.mart_financeiro_recebimento AS
SELECT
  year(data_vencimento) AS ano_vencimento,
  month(data_vencimento) AS mes_vencimento,
  date_format(data_vencimento, 'yyyy-MM') AS periodo_vencimento,
  ROUND(SUM(valor), 2) AS valor_a_receber,
  ROUND(SUM(CASE WHEN status_pagamento IN ('Pago', 'Pago com atraso') THEN valor ELSE 0.00 END), 2) AS recebido,
  ROUND(AVG(CASE WHEN data_pagamento > data_vencimento THEN datediff(data_pagamento, data_vencimento) ELSE 0 END), 1) AS atraso_medio_dias,
  ROUND(SUM(valor * taxa_pct / 100.0), 2) AS custo_taxa
FROM lakehouse_rotaperfume.silver.pagamentos
WHERE data_vencimento IS NOT NULL
GROUP BY year(data_vencimento), month(data_vencimento), date_format(data_vencimento, 'yyyy-MM');

COMMENT ON TABLE lakehouse_rotaperfume.gold.mart_financeiro_recebimento IS 'Data Mart financeiro de previsão e liquidação de recebíveis por mês de vencimento com taxa e atraso médio';
