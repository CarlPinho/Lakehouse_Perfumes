-- ==============================================================================
-- 13-fila.sql: Geração da Fila Semanal Priorizada de 200 Clientes,
--             Ferramentas do Agente de IA (Funções SQL no Unity Catalog)
--             e Testes de Qualidade com Fail-Fast
-- ==============================================================================

-- 1. CRIAÇÃO DA TABELA DA SEMANA: gold.fila_semanal
CREATE OR REPLACE TABLE lakehouse_rotaperfume.gold.fila_semanal AS
WITH
-- A. Snapshot mais recente de estoque semanal
estoque_recente AS (
  SELECT sku, saldo, ruptura, data_snapshot
  FROM (
    SELECT sku, saldo, ruptura, data_snapshot,
           ROW_NUMBER() OVER (PARTITION BY sku ORDER BY data_snapshot DESC) AS rn
    FROM lakehouse_rotaperfume.silver.estoque
  )
  WHERE rn = 1
),
-- B. Marca preferida histórica de cada cliente (maior receita na fato_vendas)
marcas_cliente AS (
  SELECT cliente_id, marca, SUM(receita) AS rec_marca,
         ROW_NUMBER() OVER (PARTITION BY cliente_id ORDER BY SUM(receita) DESC) AS rn_marca
  FROM lakehouse_rotaperfume.gold.fato_vendas
  GROUP BY cliente_id, marca
),
marca_pref AS (
  SELECT cliente_id, marca AS marca_preferida
  FROM marcas_cliente
  WHERE rn_marca = 1
),
-- C. SKUs comprados pelo cliente nos últimos 90 dias (antes do corte 2026-08-31)
skus_recentes_90d AS (
  SELECT DISTINCT cliente_id, sku
  FROM lakehouse_rotaperfume.gold.fato_vendas
  WHERE data_pedido >= date_sub(DATE'2026-08-31', 90)
),
-- D. Candidato preferencial de sugestão: SKU mais comprado da marca preferida que NÃO comprou em 90d
candidatos_pref AS (
  SELECT
    f.cliente_id,
    f.sku,
    p.descricao,
    ROW_NUMBER() OVER (PARTITION BY f.cliente_id ORDER BY SUM(f.quantidade) DESC, f.sku ASC) AS rn_sku
  FROM lakehouse_rotaperfume.gold.fato_vendas f
  JOIN marca_pref mp ON f.cliente_id = mp.cliente_id AND f.marca = mp.marca_preferida
  JOIN lakehouse_rotaperfume.gold.dim_produto p ON f.sku = p.sku
  LEFT JOIN skus_recentes_90d r ON f.cliente_id = r.cliente_id AND f.sku = r.sku
  WHERE r.sku IS NULL
  GROUP BY f.cliente_id, f.sku, p.descricao
),
-- E. Fallback 1: SKU mais comprado de QUALQUER marca que NÃO comprou em 90d
candidatos_geral AS (
  SELECT
    f.cliente_id,
    f.sku,
    p.descricao,
    ROW_NUMBER() OVER (PARTITION BY f.cliente_id ORDER BY SUM(f.quantidade) DESC, f.sku ASC) AS rn_sku
  FROM lakehouse_rotaperfume.gold.fato_vendas f
  JOIN lakehouse_rotaperfume.gold.dim_produto p ON f.sku = p.sku
  LEFT JOIN skus_recentes_90d r ON f.cliente_id = r.cliente_id AND f.sku = r.sku
  WHERE r.sku IS NULL
  GROUP BY f.cliente_id, f.sku, p.descricao
),
-- F. Fallback 2: SKU mais comprado de todos os tempos pelo cliente
candidatos_qualquer AS (
  SELECT
    f.cliente_id,
    f.sku,
    p.descricao,
    ROW_NUMBER() OVER (PARTITION BY f.cliente_id ORDER BY SUM(f.quantidade) DESC, f.sku ASC) AS rn_sku
  FROM lakehouse_rotaperfume.gold.fato_vendas f
  JOIN lakehouse_rotaperfume.gold.dim_produto p ON f.sku = p.sku
  GROUP BY f.cliente_id, f.sku, p.descricao
),
-- G. Consolidação do produto sugerido com saldo de estoque
sugestao_consolidada AS (
  SELECT
    t.cliente_id,
    coalesce(cp.sku, cg.sku, cq.sku) AS sku,
    coalesce(cp.descricao, cg.descricao, cq.descricao) AS descricao,
    coalesce(e.saldo, 0) AS saldo_estoque
  FROM (SELECT DISTINCT cliente_id FROM lakehouse_rotaperfume.gold.score_propensao) t
  LEFT JOIN candidatos_pref cp ON t.cliente_id = cp.cliente_id AND cp.rn_sku = 1
  LEFT JOIN candidatos_geral cg ON t.cliente_id = cg.cliente_id AND cg.rn_sku = 1
  LEFT JOIN candidatos_qualquer cq ON t.cliente_id = cq.cliente_id AND cq.rn_sku = 1
  LEFT JOIN estoque_recente e ON coalesce(cp.sku, cg.sku, cq.sku) = e.sku
),
-- H. PASSO CRÍTICO: 1º Junte a carteira e DESCARTE quem não é elegível (vendedor ativo e carteira vigente)
clientes_elegiveis AS (
  SELECT
    s.cliente_id,
    s.score,
    s.faixa,
    v.nome AS vendedor,
    c.razao_social,
    c.cidade,
    c.uf,
    fc.ticket_medio,
    fc.atraso_relativo,
    fc.intervalo_medio_dias,
    fc.recencia_dias,
    fc.comprou_lancamento,
    fc.valor_total,
    sug.descricao AS prod_descricao,
    sug.sku AS prod_sku,
    sug.saldo_estoque
  FROM lakehouse_rotaperfume.gold.score_propensao s
  JOIN lakehouse_rotaperfume.silver.carteira cart ON s.cliente_id = cart.cliente_id
  JOIN lakehouse_rotaperfume.silver.vendedores v ON cart.vendedor_id = v.vendedor_id
  JOIN lakehouse_rotaperfume.gold.dim_cliente c ON s.cliente_id = c.cliente_id
  JOIN lakehouse_rotaperfume.gold.features_cliente fc ON s.cliente_id = fc.cliente_id
  LEFT JOIN sugestao_consolidada sug ON s.cliente_id = sug.cliente_id
  WHERE cart.vigente = true
    AND (cart.orfao_vendedor_desligado = false OR cart.orfao_vendedor_desligado IS NULL)
    AND v.ativo = true
),
-- I. PASSO CRÍTICO: 2º ORDER BY score DESC LIMIT 200
top_200_global AS (
  SELECT *
  FROM clientes_elegiveis
  ORDER BY score DESC
  LIMIT 200
)
-- J. PASSO CRÍTICO: 3º ROW_NUMBER() OVER (PARTITION BY vendedor ORDER BY score DESC)
SELECT
  vendedor,
  CAST(ROW_NUMBER() OVER (PARTITION BY vendedor ORDER BY score DESC) AS INT) AS ordem,
  CAST(cliente_id AS INT) AS cliente_id,
  razao_social,
  cidade,
  uf,
  CAST(score AS DOUBLE) AS score,
  faixa,
  CAST(ticket_medio AS DOUBLE) AS ticket_medio,
  -- Motivo em português personalizado por cliente (do sinal mais raro ao mais comum)
  CASE
    WHEN atraso_relativo > 3 THEN
      'Compra a cada ' || format_number(intervalo_medio_dias, 0) || ' dias e está há ' || format_number(recencia_dias, 0) || ' sem pedido. Risco de perder para o concorrente.'
    WHEN atraso_relativo > 1.5 THEN
      'Está ' || format_number(atraso_relativo, 1) || ' vezes mais atrasado que o ritmo dele.'
    WHEN valor_total >= 80000 THEN
      'Cliente grande, R$ ' || format_number(valor_total, 2) || ' no ano. Manter próximo.'
    WHEN comprou_lancamento = 1 THEN
      'Comprou lançamento recente. Alta chance de repetir.'
    ELSE
      'Dentro do ritmo. Contato de manutenção.'
  END AS motivo,
  -- Sugestão de produto com saldo em estoque
  coalesce(prod_descricao, 'Produto de Alta Giro') || ' (' || coalesce(prod_sku, 'SKU') || ') — Saldo: ' || cast(saldo_estoque as string) || ' un' AS sugestao
FROM top_200_global
ORDER BY vendedor ASC, ordem ASC;

-- Comentários de Governança na Tabela e Colunas
COMMENT ON TABLE lakehouse_rotaperfume.gold.fila_semanal IS 'Fila semanal priorizada de 200 clientes para abordagem comercial com motivo explicativo e sugestão de produto';
COMMENT ON COLUMN lakehouse_rotaperfume.gold.fila_semanal.vendedor IS 'Nome do vendedor responsável pela carteira do cliente';
COMMENT ON COLUMN lakehouse_rotaperfume.gold.fila_semanal.ordem IS 'Posição de prioridade do cliente na fila daquele vendedor específico';
COMMENT ON COLUMN lakehouse_rotaperfume.gold.fila_semanal.cliente_id IS 'Identificador único do cliente no cadastro';
COMMENT ON COLUMN lakehouse_rotaperfume.gold.fila_semanal.razao_social IS 'Razão social da empresa cliente';
COMMENT ON COLUMN lakehouse_rotaperfume.gold.fila_semanal.cidade IS 'Cidade sede do cliente';
COMMENT ON COLUMN lakehouse_rotaperfume.gold.fila_semanal.uf IS 'Estado federativo do cliente';
COMMENT ON COLUMN lakehouse_rotaperfume.gold.fila_semanal.score IS 'Probabilidade prevista pelo modelo de o cliente realizar pedido em 7 dias';
COMMENT ON COLUMN lakehouse_rotaperfume.gold.fila_semanal.faixa IS 'Segmento de temperatura da propensão calculada via NTILE(4)';
COMMENT ON COLUMN lakehouse_rotaperfume.gold.fila_semanal.ticket_medio IS 'Ticket médio histórico em reais dos pedidos do cliente';
COMMENT ON COLUMN lakehouse_rotaperfume.gold.fila_semanal.motivo IS 'Justificativa comercial em português explicando por que ligar agora';
COMMENT ON COLUMN lakehouse_rotaperfume.gold.fila_semanal.sugestao IS 'Produto recomendado para oferta com base no histórico e saldo em estoque';


-- ==============================================================================
-- 2. AS QUATRO FERRAMENTAS DO AGENTE (Funções SQL no Unity Catalog)
-- ==============================================================================

-- Ferramenta 1: priorizar_carteira
CREATE OR REPLACE FUNCTION lakehouse_rotaperfume.gold.priorizar_carteira(p_vendedor STRING, p_quantos INT)
RETURNS TABLE (
  ordem INT,
  cliente_id INT,
  razao_social STRING,
  cidade STRING,
  uf STRING,
  score DOUBLE,
  faixa STRING,
  motivo STRING,
  sugestao STRING
)
COMMENT 'Retorna a lista priorizada de clientes para contato na semana de um vendedor específico, ordenada pelo score do modelo de propensão'
RETURN
  SELECT
    ordem,
    cliente_id,
    razao_social,
    cidade,
    uf,
    score,
    faixa,
    motivo,
    sugestao
  FROM lakehouse_rotaperfume.gold.fila_semanal
  WHERE vendedor = p_vendedor
    AND ordem <= p_quantos
  ORDER BY ordem ASC;

-- Ferramenta 2: contexto_cliente
CREATE OR REPLACE FUNCTION lakehouse_rotaperfume.gold.contexto_cliente(p_cliente_id INT)
RETURNS TABLE (
  cliente_id INT,
  razao_social STRING,
  cidade STRING,
  uf STRING,
  segmento STRING,
  total_pedidos BIGINT,
  receita_total DOUBLE,
  ticket_medio DOUBLE,
  primeira_compra DATE,
  ultima_compra DATE,
  dias_sem_comprar INT,
  marcas_preferidas STRING
)
COMMENT 'Fornece o contexto comercial completo e histórico consolidado de um cliente para apoiar a abordagem do vendedor'
RETURN
  WITH marcas AS (
    SELECT
      f.cliente_id,
      array_join(slice(array_agg(f.marca), 1, 3), ', ') AS marcas_preferidas
    FROM (
      SELECT cliente_id, marca, SUM(receita) AS rec
      FROM lakehouse_rotaperfume.gold.fato_vendas
      WHERE cliente_id = p_cliente_id
      GROUP BY cliente_id, marca
      ORDER BY rec DESC
    ) f
    GROUP BY f.cliente_id
  )
  SELECT
    c.cliente_id,
    c.razao_social,
    c.cidade,
    c.uf,
    c.segmento,
    c.total_pedidos,
    CAST(c.receita_acumulada AS DOUBLE) AS receita_total,
    CAST(coalesce(c.receita_acumulada, 0.0) / NULLIF(c.total_pedidos, 0) AS DOUBLE) AS ticket_medio,
    c.primeiro_pedido AS primeira_compra,
    c.ultimo_pedido AS ultima_compra,
    c.dias_sem_comprar,
    coalesce(m.marcas_preferidas, 'N/A') AS marcas_preferidas
  FROM lakehouse_rotaperfume.gold.dim_cliente c
  LEFT JOIN marcas m ON c.cliente_id = m.cliente_id
  WHERE c.cliente_id = p_cliente_id;


-- Ferramenta 3: sugerir_produtos
CREATE OR REPLACE FUNCTION lakehouse_rotaperfume.gold.sugerir_produtos(p_cliente_id INT)
RETURNS TABLE (
  sku STRING,
  descricao STRING,
  marca STRING,
  categoria STRING,
  quantidade_historica BIGINT,
  ultimo_pedido DATE,
  saldo_estoque INT,
  ruptura BOOLEAN
)
COMMENT 'Sugere produtos historicamente comprados pelo cliente que ele não comprou nos últimos 90 dias, com disponibilidade de estoque'
RETURN
  WITH estoque_recente AS (
    SELECT sku, saldo, ruptura
    FROM (
      SELECT sku, saldo, ruptura,
             ROW_NUMBER() OVER (PARTITION BY sku ORDER BY data_snapshot DESC) AS rn
      FROM lakehouse_rotaperfume.silver.estoque
    )
    WHERE rn = 1
  ),
  compras_recentes AS (
    SELECT DISTINCT sku
    FROM lakehouse_rotaperfume.gold.fato_vendas
    WHERE cliente_id = p_cliente_id
      AND data_pedido >= date_sub(DATE'2026-08-31', 90)
  )
  SELECT
    f.sku,
    p.descricao,
    f.marca,
    f.categoria,
    CAST(SUM(f.quantidade) AS BIGINT) AS quantidade_historica,
    MAX(f.data_pedido) AS ultimo_pedido,
    coalesce(e.saldo, 0) AS saldo_estoque,
    coalesce(e.ruptura, false) AS ruptura
  FROM lakehouse_rotaperfume.gold.fato_vendas f
  JOIN lakehouse_rotaperfume.gold.dim_produto p ON f.sku = p.sku
  LEFT JOIN compras_recentes cr ON f.sku = cr.sku
  LEFT JOIN estoque_recente e ON f.sku = e.sku
  WHERE f.cliente_id = p_cliente_id
    AND cr.sku IS NULL
  GROUP BY f.sku, p.descricao, f.marca, f.categoria, e.saldo, e.ruptura
  ORDER BY quantidade_historica DESC;

-- Ferramenta 4: checar_disponibilidade
CREATE OR REPLACE FUNCTION lakehouse_rotaperfume.gold.checar_disponibilidade(p_sku STRING)
RETURNS TABLE (
  sku STRING,
  descricao STRING,
  marca STRING,
  categoria STRING,
  preco_tabela DOUBLE,
  saldo INT,
  ruptura BOOLEAN,
  data_snapshot DATE
)
COMMENT 'Verifica a disponibilidade de estoque e status de ruptura de um SKU específico no snapshot mais recente'
RETURN
  WITH estoque_recente AS (
    SELECT sku, saldo, ruptura, data_snapshot
    FROM (
      SELECT sku, saldo, ruptura, data_snapshot,
             ROW_NUMBER() OVER (PARTITION BY sku ORDER BY data_snapshot DESC) AS rn
      FROM lakehouse_rotaperfume.silver.estoque
    )
    WHERE rn = 1
  )
  SELECT
    p.sku,
    p.descricao,
    p.marca,
    p.categoria,
    CAST(p.preco_tabela AS DOUBLE) AS preco_tabela,
    coalesce(e.saldo, 0) AS saldo,
    coalesce(e.ruptura, false) AS ruptura,
    e.data_snapshot
  FROM lakehouse_rotaperfume.gold.dim_produto p
  LEFT JOIN estoque_recente e ON p.sku = e.sku
  WHERE p.sku = p_sku;


-- ==============================================================================
-- 3. TRÊS TESTES DE QUALIDADE COM FAIL-FAST (raise_error)
-- ==============================================================================

SELECT
  CASE
    -- Teste 1: A fila tem exatamente 200 linhas
    WHEN (SELECT COUNT(*) FROM lakehouse_rotaperfume.gold.fila_semanal) != 200
    THEN raise_error('TESTE 1 FALHOU: A fila semanal não possui exatamente 200 linhas (contagem atual: ' || cast((SELECT COUNT(*) FROM lakehouse_rotaperfume.gold.fila_semanal) as string) || ').')

    -- Teste 2: Nenhuma linha com motivo nulo ou vazio
    WHEN (SELECT COUNT(*) FROM lakehouse_rotaperfume.gold.fila_semanal WHERE motivo IS NULL OR trim(motivo) = '') > 0
    THEN raise_error('TESTE 2 FALHOU: Existem clientes na fila semanal com motivo nulo ou em branco.')

    -- Teste 3: Nenhum score fora do intervalo [0, 1]
    WHEN (SELECT COUNT(*) FROM lakehouse_rotaperfume.gold.fila_semanal WHERE score < 0.0 OR score > 1.0) > 0
    THEN raise_error('TESTE 3 FALHOU: Existem scores na fila semanal fora do intervalo válido [0, 1].')

    ELSE 'Todos os 3 testes de qualidade da fila semanal passaram com sucesso!'
  END AS status_testes_fila;
