-- ==============================================================================
-- 02-pedidos.sql: Limpeza, Tipagem, Tratamento de Cancelamentos e Contrato de Pedidos
-- ==============================================================================

CREATE OR REPLACE TABLE lakehouse_rotaperfume.silver.pedidos AS
WITH transformado AS (
  SELECT
    CAST(pedido_id AS BIGINT) AS pedido_id,
    CAST(cliente_id AS BIGINT) AS cliente_id,
    CAST(vendedor_id AS BIGINT) AS vendedor_id,
    coalesce(try_to_date(data_pedido), try_to_date(data_pedido, 'dd/MM/yyyy')) AS data_pedido,
    trim(canal) AS canal,
    trim(status) AS status,
    (trim(status) = 'Cancelado') AS cancelado,
    CAST(valor_total AS DECIMAL(18,2)) AS valor_total,
    CASE 
      WHEN trim(status) = 'Cancelado' THEN CAST(0.00 AS DECIMAL(18,2))
      ELSE CAST(valor_total AS DECIMAL(18,2))
    END AS valor_liquido,
    current_timestamp() AS _processado_em,
    (SELECT COUNT(*) FROM lakehouse_rotaperfume.bronze.pedidos) AS _linhas_origem
  FROM lakehouse_rotaperfume.bronze.pedidos
)
SELECT
  pedido_id,
  cliente_id,
  vendedor_id,
  data_pedido,
  year(data_pedido) AS ano,
  month(data_pedido) AS mes,
  canal,
  status,
  cancelado,
  valor_total,
  valor_liquido,
  _processado_em,
  _linhas_origem
FROM transformado;

-- Contratos de Qualidade (Delta Constraints)
ALTER TABLE lakehouse_rotaperfume.silver.pedidos
  ADD CONSTRAINT pedidos_data_pedido_not_null CHECK (data_pedido IS NOT NULL);

ALTER TABLE lakehouse_rotaperfume.silver.pedidos
  ADD CONSTRAINT pedidos_cancelado_zerado CHECK (NOT cancelado OR valor_liquido = 0);

-- Documentação de Decisões de Negócio no Catálogo
COMMENT ON TABLE lakehouse_rotaperfume.silver.pedidos IS 'Tabela Silver de pedidos com tratamento de cancelamentos e isolamento de valor liquido sem perda de faturamento';
COMMENT ON COLUMN lakehouse_rotaperfume.silver.pedidos.valor_liquido IS 'Valor liquido do pedido, zerado caso o status seja Cancelado para permitir agregacao direta sem distorcao';
COMMENT ON COLUMN lakehouse_rotaperfume.silver.pedidos.cancelado IS 'Flag booleana derivada de status = Cancelado';
