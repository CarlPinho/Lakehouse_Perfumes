-- ==============================================================================
-- 08-testes.sql: Suíte de 9 Testes de Qualidade com Interrupção Automática (Fail-Fast)
-- ==============================================================================

WITH t1 AS (
  SELECT
    1 AS id,
    'Reconciliação de Receita (Gold vs. Silver)' AS teste,
    CAST(ROUND(SUM(receita), 2) AS STRING) AS valor_calculado,
    '102303828.05' AS valor_esperado,
    CASE
      WHEN abs(SUM(receita) - 102303828.05) <= 0.01 
       AND abs(SUM(receita) - (SELECT SUM(valor_liquido) FROM lakehouse_rotaperfume.silver.pedidos)) <= 0.01
      THEN 'PASSOU'
      ELSE raise_error('TESTE 1 FALHOU: Receita da Gold diverge da Silver!')
    END AS status
  FROM lakehouse_rotaperfume.gold.fato_vendas
),
t2 AS (
  SELECT
    2 AS id,
    'Unicidade de CNPJ em silver.clientes' AS teste,
    CAST(COUNT(*) - COUNT(DISTINCT cnpj) AS STRING) AS valor_calculado,
    '0' AS valor_esperado,
    CASE
      WHEN COUNT(*) - COUNT(DISTINCT cnpj) = 0 THEN 'PASSOU'
      ELSE raise_error('TESTE 2 FALHOU: Existem CNPJs duplicados na silver.clientes!')
    END AS status
  FROM lakehouse_rotaperfume.silver.clientes
),
t3 AS (
  SELECT
    3 AS id,
    'Integridade de datas em silver.pedidos' AS teste,
    CAST(COUNT(*) FILTER (WHERE data_pedido IS NULL) AS STRING) AS valor_calculado,
    '0' AS valor_esperado,
    CASE
      WHEN COUNT(*) FILTER (WHERE data_pedido IS NULL) = 0 THEN 'PASSOU'
      ELSE raise_error('TESTE 3 FALHOU: Existem pedidos com data_pedido nula!')
    END AS status
  FROM lakehouse_rotaperfume.silver.pedidos
),
t4 AS (
  SELECT
    4 AS id,
    'Receita negativa apenas em devoluções' AS teste,
    CAST(COUNT(*) FILTER (WHERE receita < 0 AND NOT devolucao) AS STRING) AS valor_calculado,
    '0' AS valor_esperado,
    CASE
      WHEN COUNT(*) FILTER (WHERE receita < 0 AND NOT devolucao) = 0 THEN 'PASSOU'
      ELSE raise_error('TESTE 4 FALHOU: Existem itens com receita negativa sem flag de devolucao!')
    END AS status
  FROM lakehouse_rotaperfume.gold.fato_vendas
),
t5 AS (
  SELECT
    5 AS id,
    'Volume de linhas em gold.fato_vendas' AS teste,
    CAST(COUNT(*) AS STRING) AS valor_calculado,
    'Entre 140000 e 250000' AS valor_esperado,
    CASE
      WHEN COUNT(*) BETWEEN 140000 AND 250000 THEN 'PASSOU'
      ELSE raise_error('TESTE 5 FALHOU: Volume de linhas da fato_vendas fora dos limites!')
    END AS status
  FROM lakehouse_rotaperfume.gold.fato_vendas
),
t6 AS (
  SELECT
    6 AS id,
    'Integridade referencial de pedido_id' AS teste,
    CAST(COUNT(*) FILTER (WHERE p.pedido_id IS NULL) AS STRING) AS valor_calculado,
    '0' AS valor_esperado,
    CASE
      WHEN COUNT(*) FILTER (WHERE p.pedido_id IS NULL) = 0 THEN 'PASSOU'
      ELSE raise_error('TESTE 6 FALHOU: Existem pedido_id na Gold que nao existem na Silver!')
    END AS status
  FROM lakehouse_rotaperfume.gold.fato_vendas f
  LEFT JOIN lakehouse_rotaperfume.silver.pedidos p ON f.pedido_id = p.pedido_id
),
t7 AS (
  SELECT
    7 AS id,
    'Integridade referencial de cliente_id' AS teste,
    CAST(COUNT(*) FILTER (WHERE c.cliente_id IS NULL) AS STRING) AS valor_calculado,
    '0' AS valor_esperado,
    CASE
      WHEN COUNT(*) FILTER (WHERE c.cliente_id IS NULL) = 0 THEN 'PASSOU'
      ELSE raise_error('TESTE 7 FALHOU: Existem cliente_id na Gold que nao existem na Silver!')
    END AS status
  FROM lakehouse_rotaperfume.gold.fato_vendas f
  LEFT JOIN lakehouse_rotaperfume.silver.clientes c ON f.cliente_id = c.cliente_id
),
t8 AS (
  SELECT
    8 AS id,
    'Conformidade de receita entre Mart Produto e Fato' AS teste,
    CAST(ROUND(SUM(m.receita), 2) AS STRING) AS valor_calculado,
    CAST(ROUND((SELECT SUM(receita) FROM lakehouse_rotaperfume.gold.fato_vendas), 2) AS STRING) AS valor_esperado,
    CASE
      WHEN abs(SUM(m.receita) - (SELECT SUM(receita) FROM lakehouse_rotaperfume.gold.fato_vendas)) <= 0.01 THEN 'PASSOU'
      ELSE raise_error('TESTE 8 FALHOU: mart_produto_performance diverge do faturamento da fato_vendas!')
    END AS status
  FROM lakehouse_rotaperfume.gold.mart_produto_performance m
),
t9 AS (
  SELECT
    9 AS id,
    'Formatação estrita de CNPJ (14 dígitos)' AS teste,
    CAST(COUNT(*) FILTER (WHERE length(cnpj) <> 14) AS STRING) AS valor_calculado,
    '0' AS valor_esperado,
    CASE
      WHEN COUNT(*) FILTER (WHERE length(cnpj) <> 14) = 0 THEN 'PASSOU'
      ELSE raise_error('TESTE 9 FALHOU: Existem CNPJs com tamanho diferente de 14 digitos!')
    END AS status
  FROM lakehouse_rotaperfume.silver.clientes
)
SELECT id, teste, valor_calculado, valor_esperado, status FROM t1
UNION ALL SELECT id, teste, valor_calculado, valor_esperado, status FROM t2
UNION ALL SELECT id, teste, valor_calculado, valor_esperado, status FROM t3
UNION ALL SELECT id, teste, valor_calculado, valor_esperado, status FROM t4
UNION ALL SELECT id, teste, valor_calculado, valor_esperado, status FROM t5
UNION ALL SELECT id, teste, valor_calculado, valor_esperado, status FROM t6
UNION ALL SELECT id, teste, valor_calculado, valor_esperado, status FROM t7
UNION ALL SELECT id, teste, valor_calculado, valor_esperado, status FROM t8
UNION ALL SELECT id, teste, valor_calculado, valor_esperado, status FROM t9
ORDER BY id;
