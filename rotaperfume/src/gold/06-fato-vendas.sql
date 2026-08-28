-- ==============================================================================
-- 06-fato-vendas.sql: Fato Central de Vendas do Lakehouse Rota Perfume
-- ==============================================================================
--
-- CONTRATO DA FATO_VENDAS:
-- ------------------------------------------------------------------------------
-- Granularidade : Uma linha por ITEM de pedido (item_id).
-- Filtros       : Exclui pedidos cancelados (NOT p.cancelado). Devoluções são INCLUÍDAS.
-- Dimensões     : data_pedido, ano, mes, canal, cliente_id, razao_social, segmento,
--                 cidade, vendedor_id, sku, categoria, marca, nota_olfativa.
-- Métricas      : quantidade, preco_praticado, receita, custo, margem, devolucao.
--
-- REGRAS E FÓRMULAS DE NEGÓCIO:
-- - custo   = quantidade * custo_unitario do produto
-- - receita = quantidade * preco_praticado do item
-- - margem  = receita - custo
-- - Devoluções entram com quantidade e receita NEGATIVAS e flag devolucao = true.
--
-- POR QUE A DEVOLUÇÃO FICA DENTRO DO FATO:
-- Se a devolução fosse excluída, a Gold somaria R$ 103,57 mi e a Silver R$ 102,30 mi,
-- gerando R$ 1,26 milhão de divergência contábil entre camadas.
-- Para obter o faturamento bruto, basta filtrar: SUM(receita) FILTER (WHERE NOT devolucao).
-- ==============================================================================

CREATE OR REPLACE TABLE lakehouse_rotaperfume.gold.fato_vendas
PARTITIONED BY (ano, mes) AS
WITH expandido AS (
  SELECT
    cliente_id AS cliente_id_canonico,
    razao_social,
    segmento,
    cidade,
    explode(array_append(coalesce(cliente_ids_duplicados, array()), cast(cliente_id as string))) AS id_str
  FROM lakehouse_rotaperfume.silver.clientes
),
mapa_clientes AS (
  SELECT
    cliente_id_canonico,
    razao_social,
    segmento,
    cidade,
    cast(id_str as bigint) AS cliente_id_origem
  FROM expandido
)
SELECT
  i.item_id,
  i.pedido_id,
  p.data_pedido,
  p.canal,
  c.cliente_id_canonico AS cliente_id,
  c.razao_social,
  c.segmento,
  c.cidade,
  p.vendedor_id,
  i.sku,
  pr.categoria,
  pr.marca,
  pr.nota_olfativa,
  i.quantidade,
  i.preco_praticado,
  ROUND(i.quantidade * i.preco_praticado, 2) AS receita,
  ROUND(i.quantidade * pr.custo_unitario, 2) AS custo,
  ROUND(i.quantidade * i.preco_praticado - i.quantidade * pr.custo_unitario, 2) AS margem,
  i.devolucao,
  p.ano,
  p.mes
FROM lakehouse_rotaperfume.silver.itens_pedido i
JOIN lakehouse_rotaperfume.silver.pedidos p ON p.pedido_id = i.pedido_id
JOIN lakehouse_rotaperfume.silver.produtos pr ON pr.sku = i.sku
JOIN mapa_clientes c ON c.cliente_id_origem = p.cliente_id
WHERE NOT p.cancelado;

-- Documentação de Negócio no Catálogo (Unity Catalog)
COMMENT ON TABLE lakehouse_rotaperfume.gold.fato_vendas IS 'Tabela fato central de vendas no grão de item de pedido, consolidando receitas, custos e margens líquidas';

COMMENT ON COLUMN lakehouse_rotaperfume.gold.fato_vendas.item_id IS 'Identificador exclusivo do item na transação de venda';
COMMENT ON COLUMN lakehouse_rotaperfume.gold.fato_vendas.pedido_id IS 'Identificador do pedido de venda ao qual o item pertence';
COMMENT ON COLUMN lakehouse_rotaperfume.gold.fato_vendas.data_pedido IS 'Data em que o pedido foi registrado';
COMMENT ON COLUMN lakehouse_rotaperfume.gold.fato_vendas.canal IS 'Canal de comercialização do pedido (ex.: Loja Física, Visita, E-commerce)';
COMMENT ON COLUMN lakehouse_rotaperfume.gold.fato_vendas.cliente_id IS 'Identificador único do cliente comprador';
COMMENT ON COLUMN lakehouse_rotaperfume.gold.fato_vendas.razao_social IS 'Razão social padronizada do cliente';
COMMENT ON COLUMN lakehouse_rotaperfume.gold.fato_vendas.segmento IS 'Classificação mercadológica da empresa cliente';
COMMENT ON COLUMN lakehouse_rotaperfume.gold.fato_vendas.cidade IS 'Município do cliente';
COMMENT ON COLUMN lakehouse_rotaperfume.gold.fato_vendas.vendedor_id IS 'Identificador do vendedor responsável pela negociação';
COMMENT ON COLUMN lakehouse_rotaperfume.gold.fato_vendas.sku IS 'Código SKU único do produto comercializado';
COMMENT ON COLUMN lakehouse_rotaperfume.gold.fato_vendas.categoria IS 'Linha de produto ou categoria cosmética';
COMMENT ON COLUMN lakehouse_rotaperfume.gold.fato_vendas.marca IS 'Marca do perfume ou cosmético';
COMMENT ON COLUMN lakehouse_rotaperfume.gold.fato_vendas.nota_olfativa IS 'Perfil aromático ou nota olfativa predominante';
COMMENT ON COLUMN lakehouse_rotaperfume.gold.fato_vendas.quantidade IS 'Quantidade física vendida (negativa em caso de devolução)';
COMMENT ON COLUMN lakehouse_rotaperfume.gold.fato_vendas.preco_praticado IS 'Preço unitário efetivamente cobrado pelo item';
COMMENT ON COLUMN lakehouse_rotaperfume.gold.fato_vendas.receita IS 'Receita total da linha (quantidade * preco_praticado). Negativa em devoluções';
COMMENT ON COLUMN lakehouse_rotaperfume.gold.fato_vendas.custo IS 'Custo mercadológico total (quantidade * custo_unitario). Revertido em devoluções';
COMMENT ON COLUMN lakehouse_rotaperfume.gold.fato_vendas.margem IS 'Receita menos custo do produto. Não considera desconto comercial nem frete';
COMMENT ON COLUMN lakehouse_rotaperfume.gold.fato_vendas.devolucao IS 'Flag booleana indicando se a linha representa uma devolução de mercadoria';
COMMENT ON COLUMN lakehouse_rotaperfume.gold.fato_vendas.ano IS 'Ano do pedido utilizado como partição física';
COMMENT ON COLUMN lakehouse_rotaperfume.gold.fato_vendas.mes IS 'Mês do pedido utilizado como partição física';
