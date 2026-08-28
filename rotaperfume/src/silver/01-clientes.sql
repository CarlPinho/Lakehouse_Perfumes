-- ==============================================================================
-- 01-clientes.sql: Limpeza, Tipagem, Deduplicação e Contrato da Entidade Clientes
-- ==============================================================================

CREATE OR REPLACE TABLE lakehouse_rotaperfume.silver.clientes AS
WITH normalizado AS (
  SELECT
    cliente_id,
    lpad(regexp_replace(trim(cnpj), '[^0-9]', ''), 14, '0') AS cnpj,
    regexp_replace(initcap(trim(razao_social)), ' +', ' ') AS razao_social,
    trim(segmento) AS segmento,
    trim(cidade) AS cidade,
    trim(uf) AS uf,
    trim(bairro) AS bairro,
    coalesce(try_to_date(data_cadastro), try_to_date(data_cadastro, 'dd/MM/yyyy')) AS data_cadastro,
    CASE WHEN upper(trim(ativo)) = 'S' THEN true ELSE false END AS ativo
  FROM lakehouse_rotaperfume.bronze.clientes
),
ranqueado AS (
  SELECT
    *,
    row_number() OVER (
      PARTITION BY cnpj
      ORDER BY data_cadastro ASC, cliente_id ASC
    ) AS rn,
    collect_list(cliente_id) OVER (
      PARTITION BY cnpj
    ) AS todos_ids
  FROM normalizado
)
SELECT
  CAST(cliente_id AS BIGINT) AS cliente_id,
  cnpj,
  razao_social,
  segmento,
  cidade,
  uf,
  bairro,
  data_cadastro,
  ativo,
  CASE 
    WHEN size(array_remove(todos_ids, cliente_id)) > 0 
    THEN array_remove(todos_ids, cliente_id) 
    ELSE CAST(NULL AS ARRAY<STRING>) 
  END AS cliente_ids_duplicados,
  current_timestamp() AS _processado_em,
  (SELECT COUNT(*) FROM lakehouse_rotaperfume.bronze.clientes) AS _linhas_origem
FROM ranqueado
WHERE rn = 1;

-- Contratos de Qualidade (Delta Constraints)
ALTER TABLE lakehouse_rotaperfume.silver.clientes
  ADD CONSTRAINT clientes_cnpj_14 CHECK (length(cnpj) = 14);

ALTER TABLE lakehouse_rotaperfume.silver.clientes
  ADD CONSTRAINT clientes_data_cadastro_not_null CHECK (data_cadastro IS NOT NULL);

-- Documentação de Decisões de Limpeza no Catálogo
COMMENT ON TABLE lakehouse_rotaperfume.silver.clientes IS 'Tabela Silver de clientes com CNPJ padronizado em 14 digitos, deduplicacao pelo cadastro mais antigo e historico de duplicatas';
COMMENT ON COLUMN lakehouse_rotaperfume.silver.clientes.cnpj IS 'CNPJ normalizado com 14 digitos numericos, mantendo zeros a esquerda';
COMMENT ON COLUMN lakehouse_rotaperfume.silver.clientes.cliente_ids_duplicados IS 'Array com os IDs descartados na deduplicacao por CNPJ para rastreabilidade';
