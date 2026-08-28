-- ==============================================================================
-- 05-dimensoes.sql: Criação das Quatro Dimensões Conformadas da Camada Gold
-- ==============================================================================

-- 1. Dimensão Cliente (com métricas históricas e consolidação de clientes duplicados)
CREATE OR REPLACE TABLE lakehouse_rotaperfume.gold.dim_cliente AS
WITH expandido AS (
  SELECT
    cliente_id AS cliente_id_canonico,
    explode(array_append(coalesce(cliente_ids_duplicados, array()), cast(cliente_id as string))) AS id_str
  FROM lakehouse_rotaperfume.silver.clientes
),
mapa_clientes AS (
  SELECT
    cliente_id_canonico,
    cast(id_str as bigint) AS cliente_id_origem
  FROM expandido
),
pedidos_com_cliente_canonico AS (
  SELECT
    p.pedido_id,
    c.cliente_id_canonico AS cliente_id,
    p.data_pedido,
    p.valor_liquido
  FROM lakehouse_rotaperfume.silver.pedidos p
  JOIN mapa_clientes c ON c.cliente_id_origem = p.cliente_id
  WHERE NOT p.cancelado
),
metricas_pedidos AS (
  SELECT
    cliente_id,
    MIN(data_pedido) AS primeiro_pedido,
    MAX(data_pedido) AS ultimo_pedido,
    COUNT(DISTINCT pedido_id) AS total_pedidos,
    ROUND(SUM(valor_liquido), 2) AS receita_acumulada
  FROM pedidos_com_cliente_canonico
  GROUP BY cliente_id
)
SELECT
  c.cliente_id,
  c.cnpj,
  c.razao_social,
  c.segmento,
  c.cidade,
  c.uf,
  c.data_cadastro,
  m.primeiro_pedido,
  m.ultimo_pedido,
  coalesce(m.total_pedidos, 0) AS total_pedidos,
  coalesce(m.receita_acumulada, 0.00) AS receita_acumulada,
  datediff(current_date(), m.ultimo_pedido) AS dias_sem_comprar,
  c.ativo
FROM lakehouse_rotaperfume.silver.clientes c
LEFT JOIN metricas_pedidos m ON c.cliente_id = m.cliente_id;

COMMENT ON TABLE lakehouse_rotaperfume.gold.dim_cliente IS 'Dimensão conformada de clientes com histórico de compras e métricas de recência';
COMMENT ON COLUMN lakehouse_rotaperfume.gold.dim_cliente.dias_sem_comprar IS 'Dias corridos desde o último pedido válido do cliente até a data atual';
COMMENT ON COLUMN lakehouse_rotaperfume.gold.dim_cliente.receita_acumulada IS 'Receita total líquida gerada pelo cliente ao longo do histórico';

-- 2. Dimensão Produto
CREATE OR REPLACE TABLE lakehouse_rotaperfume.gold.dim_produto AS
SELECT
  sku,
  descricao,
  categoria,
  marca,
  nota_olfativa,
  custo_unitario AS custo,
  preco_tabela,
  data_lancamento,
  (NOT ativo) AS descontinuado
FROM lakehouse_rotaperfume.silver.produtos;

COMMENT ON TABLE lakehouse_rotaperfume.gold.dim_produto IS 'Dimensão conformada de produtos com atributos de mercadologia, custos e status de descontinuação';
COMMENT ON COLUMN lakehouse_rotaperfume.gold.dim_produto.descontinuado IS 'Flag booleana indicando se o SKU não está mais ativo para novas vendas';

-- 3. Dimensão Vendedor
CREATE OR REPLACE TABLE lakehouse_rotaperfume.gold.dim_vendedor AS
SELECT
  vendedor_id,
  nome,
  regiao,
  uf,
  data_admissao,
  data_desligamento,
  meta_mensal,
  ativo
FROM lakehouse_rotaperfume.silver.vendedores;

COMMENT ON TABLE lakehouse_rotaperfume.gold.dim_vendedor IS 'Dimensão conformada de vendedores com região de atuação e metas comerciais';

-- 4. Dimensão Calendário (24 meses: 01/09/2024 a 31/08/2026)
CREATE OR REPLACE TABLE lakehouse_rotaperfume.gold.dim_calendario AS
WITH dias AS (
  SELECT explode(sequence(to_date('2024-09-01'), to_date('2026-08-31'), interval 1 day)) AS data
)
SELECT
  data,
  year(data) AS ano,
  month(data) AS mes,
  date_format(data, 'MMMM') AS nome_mes,
  quarter(data) AS trimestre,
  dayofweek(data) AS dia_semana,
  date_format(data, 'EEEE') AS nome_dia_semana,
  (month(data) IN (4, 6, 10)) AS mes_pico_setor
FROM dias;

COMMENT ON TABLE lakehouse_rotaperfume.gold.dim_calendario IS 'Dimensão de tempo contínua cobrindo 24 meses do ciclo do projeto com marcação de sazonalidade';
COMMENT ON COLUMN lakehouse_rotaperfume.gold.dim_calendario.mes_pico_setor IS 'Flag que identifica meses de alta demanda do setor de perfumaria (abril, junho e outubro)';
