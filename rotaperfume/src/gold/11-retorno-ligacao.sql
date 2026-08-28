-- ==============================================================================
-- 11-retorno-ligacao.sql: Tabela do Caminho de Volta (Retorno de Ligações)
--                        e Views Analíticas Complementares
-- ==============================================================================

-- 1. TABELA DO CAMINHO DE VOLTA: gold.retorno_ligacao
-- IMPORTANTE: IF NOT EXISTS é obrigatório pois os dados são alimentados pelos vendedores.
CREATE TABLE IF NOT EXISTS lakehouse_rotaperfume.gold.retorno_ligacao (
  cliente_id INT,
  vendedor STRING,
  status STRING,
  comentario STRING,
  registrado_em TIMESTAMP,
  registrado_por STRING,
  _referencia DATE
);

-- Comentários de Governança na Tabela e em TODAS as Colunas (auditados pela governança)
COMMENT ON TABLE lakehouse_rotaperfume.gold.retorno_ligacao IS 'Registro de feedback e retorno das abordagens comerciais realizadas pelos vendedores';
COMMENT ON COLUMN lakehouse_rotaperfume.gold.retorno_ligacao.cliente_id IS 'Identificador único do cliente contatado';
COMMENT ON COLUMN lakehouse_rotaperfume.gold.retorno_ligacao.vendedor IS 'Nome do vendedor que realizou a ligação';
COMMENT ON COLUMN lakehouse_rotaperfume.gold.retorno_ligacao.status IS 'Desfecho da ligação: vendeu, vai_pensar, sem_interesse ou nao_atendeu';
COMMENT ON COLUMN lakehouse_rotaperfume.gold.retorno_ligacao.comentario IS 'Observações livres registradas pelo vendedor sobre a conversa';
COMMENT ON COLUMN lakehouse_rotaperfume.gold.retorno_ligacao.registrado_em IS 'Data e hora exatas do registro do retorno no sistema';
COMMENT ON COLUMN lakehouse_rotaperfume.gold.retorno_ligacao.registrado_por IS 'Endereço de e-mail do usuário que registrou a interação';
COMMENT ON COLUMN lakehouse_rotaperfume.gold.retorno_ligacao._referencia IS 'Data de referência da semana da fila trabalhada';

-- 2. VIEWS ANALÍTICAS COMPLEMENTARES PARA O GENIE SPACE DA DIREÇÃO

-- View A: Clientes em Risco
CREATE OR REPLACE VIEW lakehouse_rotaperfume.gold.clientes_em_risco AS
SELECT
  c.cliente_id,
  c.razao_social,
  c.segmento,
  c.cidade,
  c.uf,
  c.dias_sem_comprar,
  CAST(c.receita_acumulada AS DOUBLE) AS receita_acumulada,
  coalesce(s.score, 0.0) AS score,
  coalesce(s.faixa, 'Fria') AS faixa
FROM lakehouse_rotaperfume.gold.dim_cliente c
LEFT JOIN lakehouse_rotaperfume.gold.score_propensao s ON c.cliente_id = s.cliente_id
WHERE c.dias_sem_comprar > 60 OR s.faixa = 'Fria';

COMMENT ON TABLE lakehouse_rotaperfume.gold.clientes_em_risco IS 'Visão analítica de clientes em risco com alta inatividade ou baixa propensão de compra';

-- View B: Ranking de Marcas
CREATE OR REPLACE VIEW lakehouse_rotaperfume.gold.ranking_marcas AS
SELECT
  marca,
  CAST(ROUND(SUM(receita), 2) AS DOUBLE) AS receita_total,
  CAST(ROUND(SUM(margem), 2) AS DOUBLE) AS margem_total,
  COUNT(DISTINCT pedido_id) AS total_pedidos,
  COUNT(DISTINCT cliente_id) AS total_clientes,
  CAST(ROUND(SUM(margem) / NULLIF(SUM(receita), 0), 4) AS DOUBLE) AS margem_pct,
  DENSE_RANK() OVER (ORDER BY SUM(receita) DESC) AS rank_receita
FROM lakehouse_rotaperfume.gold.fato_vendas
GROUP BY marca;

COMMENT ON TABLE lakehouse_rotaperfume.gold.ranking_marcas IS 'Ranking de marcas por faturamento líquido acumulado, margem e volume de pedidos';

-- View C: Receita Mensal
CREATE OR REPLACE VIEW lakehouse_rotaperfume.gold.receita_mensal AS
SELECT
  ano,
  mes,
  DATE_TRUNC('month', data_pedido) AS data_mes,
  CAST(ROUND(SUM(receita), 2) AS DOUBLE) AS receita,
  CAST(ROUND(SUM(margem), 2) AS DOUBLE) AS margem,
  COUNT(DISTINCT pedido_id) AS pedidos,
  COUNT(DISTINCT cliente_id) AS clientes_ativos,
  CAST(ROUND(SUM(receita) / NULLIF(COUNT(DISTINCT pedido_id), 0), 2) AS DOUBLE) AS ticket_medio
FROM lakehouse_rotaperfume.gold.fato_vendas
GROUP BY ano, mes, DATE_TRUNC('month', data_pedido);

COMMENT ON TABLE lakehouse_rotaperfume.gold.receita_mensal IS 'Evolução mensal histórica da receita, margem, total de pedidos e ticket médio';
