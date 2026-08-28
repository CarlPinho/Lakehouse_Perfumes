-- ==============================================================================
-- 03-itens-e-produtos.sql: Limpeza, Tipagem e Contratos de Produtos e Itens de Pedido
-- ==============================================================================

-- 1. Tabela Silver de Produtos
CREATE OR REPLACE TABLE lakehouse_rotaperfume.silver.produtos AS
SELECT
  trim(sku) AS sku,
  trim(descricao) AS descricao,
  trim(categoria) AS categoria,
  trim(marca) AS marca,
  trim(nota_olfativa) AS nota_olfativa,
  CAST(preco_tabela AS DECIMAL(18,2)) AS preco_tabela,
  CAST(custo_unitario AS DECIMAL(18,2)) AS custo_unitario,
  trim(unidade) AS unidade,
  (upper(trim(ativo)) = 'S') AS ativo,
  coalesce(try_to_date(data_lancamento), try_to_date(data_lancamento, 'dd/MM/yyyy')) AS data_lancamento,
  current_timestamp() AS _processado_em,
  (SELECT COUNT(*) FROM lakehouse_rotaperfume.bronze.produtos) AS _linhas_origem
FROM lakehouse_rotaperfume.bronze.produtos;

COMMENT ON TABLE lakehouse_rotaperfume.silver.produtos IS 'Tabela Silver de catalogo de produtos com precos tipados e status de atividade padronizado';

-- 2. Tabela Silver de Itens de Pedido
CREATE OR REPLACE TABLE lakehouse_rotaperfume.silver.itens_pedido AS
SELECT
  CAST(i.item_id AS BIGINT) AS item_id,
  CAST(i.pedido_id AS BIGINT) AS pedido_id,
  trim(i.sku) AS sku,
  CAST(i.quantidade AS INT) AS quantidade,
  abs(CAST(i.quantidade AS INT)) AS quantidade_abs,
  (CAST(i.quantidade AS INT) < 0) AS devolucao,
  CAST(i.preco_praticado AS DECIMAL(18,2)) AS preco_praticado,
  CAST(i.desconto_pct AS DECIMAL(5,2)) AS desconto_pct,
  CAST(i.valor_bruto AS DECIMAL(18,2)) AS valor_bruto,
  (p.ativo IS FALSE) AS sku_descontinuado,
  current_timestamp() AS _processado_em,
  (SELECT COUNT(*) FROM lakehouse_rotaperfume.bronze.itens_pedido) AS _linhas_origem
FROM lakehouse_rotaperfume.bronze.itens_pedido i
LEFT JOIN lakehouse_rotaperfume.silver.produtos p ON trim(i.sku) = p.sku;

-- Contrato de Qualidade (Delta Constraints)
ALTER TABLE lakehouse_rotaperfume.silver.itens_pedido
  ADD CONSTRAINT itens_pedido_quantidade_abs_gt_zero CHECK (quantidade_abs > 0);

-- Documentação de Decisões de Negócio no Catálogo
COMMENT ON TABLE lakehouse_rotaperfume.silver.itens_pedido IS 'Tabela Silver de itens de pedido com sinalizacao de devolucoes e identificacao de produtos descontinuados';
COMMENT ON COLUMN lakehouse_rotaperfume.silver.itens_pedido.devolucao IS 'Flag booleana indicando devolucao derivada de quantidade negativa';
COMMENT ON COLUMN lakehouse_rotaperfume.silver.itens_pedido.quantidade_abs IS 'Quantidade em valor absoluto para calculos volumetricos positivos';
COMMENT ON COLUMN lakehouse_rotaperfume.silver.itens_pedido.sku_descontinuado IS 'Flag booleana indicando que o produto correspondente foi descontinuado';
