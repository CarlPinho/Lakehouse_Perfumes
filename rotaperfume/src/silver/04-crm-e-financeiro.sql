-- ==============================================================================
-- 04-crm-e-financeiro.sql: Limpeza e Tipagem de Vendedores, Carteira, Oportunidades,
--                         Visitas, Pagamentos e Estoque
-- ==============================================================================

-- 1. Tabela Silver de Vendedores
CREATE OR REPLACE TABLE lakehouse_rotaperfume.silver.vendedores AS
SELECT
  CAST(vendedor_id AS BIGINT) AS vendedor_id,
  trim(nome) AS nome,
  trim(regiao) AS regiao,
  trim(uf) AS uf,
  coalesce(try_to_date(data_admissao), try_to_date(data_admissao, 'dd/MM/yyyy')) AS data_admissao,
  coalesce(try_to_date(data_desligamento), try_to_date(data_desligamento, 'dd/MM/yyyy')) AS data_desligamento,
  CAST(meta_mensal AS DECIMAL(18,2)) AS meta_mensal,
  (coalesce(try_to_date(data_desligamento), try_to_date(data_desligamento, 'dd/MM/yyyy')) IS NULL) AS ativo,
  current_timestamp() AS _processado_em,
  (SELECT COUNT(*) FROM lakehouse_rotaperfume.bronze.vendedores) AS _linhas_origem
FROM lakehouse_rotaperfume.bronze.vendedores;

COMMENT ON TABLE lakehouse_rotaperfume.silver.vendedores IS 'Tabela Silver de vendedores com tipagem de datas e metas financeiras';

-- 2. Tabela Silver de Carteira (com identificação de vendedores desligados)
CREATE OR REPLACE TABLE lakehouse_rotaperfume.silver.carteira AS
SELECT
  CAST(c.carteira_id AS BIGINT) AS carteira_id,
  CAST(c.cliente_id AS BIGINT) AS cliente_id,
  CAST(c.vendedor_id AS BIGINT) AS vendedor_id,
  coalesce(try_to_date(c.data_inicio), try_to_date(c.data_inicio, 'dd/MM/yyyy')) AS data_inicio,
  coalesce(try_to_date(c.data_fim), try_to_date(c.data_fim, 'dd/MM/yyyy')) AS data_fim,
  (coalesce(try_to_date(c.data_fim), try_to_date(c.data_fim, 'dd/MM/yyyy')) IS NULL AND v.ativo IS TRUE) AS vigente,
  (coalesce(try_to_date(c.data_fim), try_to_date(c.data_fim, 'dd/MM/yyyy')) IS NULL AND v.ativo IS FALSE) AS orfao_vendedor_desligado,
  current_timestamp() AS _processado_em,
  (SELECT COUNT(*) FROM lakehouse_rotaperfume.bronze.carteira) AS _linhas_origem
FROM lakehouse_rotaperfume.bronze.carteira c
LEFT JOIN lakehouse_rotaperfume.silver.vendedores v ON CAST(c.vendedor_id AS BIGINT) = v.vendedor_id;

COMMENT ON TABLE lakehouse_rotaperfume.silver.carteira IS 'Tabela Silver de carteira de clientes com identificacao de registros orfaos por desligamento de vendedor';
COMMENT ON COLUMN lakehouse_rotaperfume.silver.carteira.vigente IS 'Flag indicando se a relacao comercial esta ativa respeitando data_fim e status do vendedor';
COMMENT ON COLUMN lakehouse_rotaperfume.silver.carteira.orfao_vendedor_desligado IS 'Flag indicando cliente ativo associado a vendedor que ja foi desligado';

-- 3. Tabela Silver de Oportunidades
CREATE OR REPLACE TABLE lakehouse_rotaperfume.silver.oportunidades AS
SELECT
  CAST(oportunidade_id AS BIGINT) AS oportunidade_id,
  CAST(cliente_id AS BIGINT) AS cliente_id,
  CAST(vendedor_id AS BIGINT) AS vendedor_id,
  trim(origem) AS origem,
  coalesce(try_to_date(data_abertura), try_to_date(data_abertura, 'dd/MM/yyyy')) AS data_abertura,
  trim(etapa) AS etapa,
  (trim(etapa) = 'Fechado ganho') AS ganha,
  (trim(etapa) = 'Fechado perdido') AS perdida,
  CAST(probabilidade_pct AS INT) AS probabilidade_pct,
  CAST(valor_estimado AS DECIMAL(18,2)) AS valor_estimado,
  coalesce(try_to_date(data_fechamento), try_to_date(data_fechamento, 'dd/MM/yyyy')) AS data_fechamento,
  CAST(ciclo_dias AS INT) AS ciclo_dias,
  trim(motivo_perda) AS motivo_perda,
  current_timestamp() AS _processado_em,
  (SELECT COUNT(*) FROM lakehouse_rotaperfume.bronze.oportunidades) AS _linhas_origem
FROM lakehouse_rotaperfume.bronze.oportunidades;

COMMENT ON TABLE lakehouse_rotaperfume.silver.oportunidades IS 'Tabela Silver de oportunidades do CRM com etapas padronizadas e flags de conversao';
COMMENT ON COLUMN lakehouse_rotaperfume.silver.oportunidades.ganha IS 'Flag booleana derivada da etapa Fechado ganho';
COMMENT ON COLUMN lakehouse_rotaperfume.silver.oportunidades.perdida IS 'Flag booleana derivada da etapa Fechado perdido';

-- 4. Tabela Silver de Visitas
CREATE OR REPLACE TABLE lakehouse_rotaperfume.silver.visitas AS
SELECT
  CAST(visita_id AS BIGINT) AS visita_id,
  CAST(cliente_id AS BIGINT) AS cliente_id,
  CAST(vendedor_id AS BIGINT) AS vendedor_id,
  coalesce(try_to_date(data_visita), try_to_date(data_visita, 'dd/MM/yyyy')) AS data_visita,
  trim(resultado) AS resultado,
  CAST(duracao_min AS INT) AS duracao_min,
  current_timestamp() AS _processado_em,
  (SELECT COUNT(*) FROM lakehouse_rotaperfume.bronze.visitas) AS _linhas_origem
FROM lakehouse_rotaperfume.bronze.visitas;

COMMENT ON TABLE lakehouse_rotaperfume.silver.visitas IS 'Tabela Silver de visitas comerciais realizadas com tipagem de duracao e datas';

-- 5. Tabela Silver de Pagamentos
CREATE OR REPLACE TABLE lakehouse_rotaperfume.silver.pagamentos AS
SELECT
  CAST(pagamento_id AS BIGINT) AS pagamento_id,
  CAST(pedido_id AS BIGINT) AS pedido_id,
  trim(forma_pagamento) AS forma_pagamento,
  CAST(parcelas AS INT) AS parcelas,
  CAST(valor AS DECIMAL(18,2)) AS valor,
  CAST(taxa_pct AS DECIMAL(5,2)) AS taxa_pct,
  CAST(valor_liquido AS DECIMAL(18,2)) AS valor_liquido,
  coalesce(try_to_date(data_vencimento), try_to_date(data_vencimento, 'dd/MM/yyyy')) AS data_vencimento,
  coalesce(try_to_date(data_pagamento), try_to_date(data_pagamento, 'dd/MM/yyyy')) AS data_pagamento,
  trim(status_pagamento) AS status_pagamento,
  current_timestamp() AS _processado_em,
  (SELECT COUNT(*) FROM lakehouse_rotaperfume.bronze.pagamentos) AS _linhas_origem
FROM lakehouse_rotaperfume.bronze.pagamentos;

COMMENT ON TABLE lakehouse_rotaperfume.silver.pagamentos IS 'Tabela Silver de pagamentos e transacoes financeiras com valores monetarios tipados';

-- 6. Tabela Silver de Estoque
CREATE OR REPLACE TABLE lakehouse_rotaperfume.silver.estoque AS
SELECT
  coalesce(try_to_date(data_snapshot), try_to_date(data_snapshot, 'dd/MM/yyyy')) AS data_snapshot,
  trim(sku) AS sku,
  CAST(saldo AS INT) AS saldo,
  (CAST(saldo AS INT) = 0) AS ruptura,
  current_timestamp() AS _processado_em,
  (SELECT COUNT(*) FROM lakehouse_rotaperfume.bronze.estoque) AS _linhas_origem
FROM lakehouse_rotaperfume.bronze.estoque;

COMMENT ON TABLE lakehouse_rotaperfume.silver.estoque IS 'Tabela Silver de snapshot de estoque com identificacao de ruptura de saldo';
COMMENT ON COLUMN lakehouse_rotaperfume.silver.estoque.ruptura IS 'Flag booleana de ruptura indicando saldo zerado de produto';
