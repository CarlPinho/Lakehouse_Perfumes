WITH retorno_recente AS (
  SELECT
    cliente_id,
    status,
    ROW_NUMBER() OVER (PARTITION BY cliente_id ORDER BY registrado_em DESC) AS rn
  FROM lakehouse_rotaperfume.gold.retorno_ligacao
),
fila_com_retorno AS (
  SELECT
    f.vendedor,
    f.cliente_id,
    r.status
  FROM lakehouse_rotaperfume.gold.fila_semanal f
  LEFT JOIN retorno_recente r ON f.cliente_id = r.cliente_id AND r.rn = 1
)
SELECT
  vendedor,
  COUNT(*) AS na_fila,
  COUNT(status) AS trabalhados,
  COUNT(CASE WHEN status = 'vendeu' THEN 1 END) AS vendeu,
  COUNT(CASE WHEN status = 'vai_pensar' THEN 1 END) AS vai_pensar,
  COUNT(CASE WHEN status = 'sem_interesse' THEN 1 END) AS sem_interesse,
  COUNT(CASE WHEN status = 'nao_atendeu' THEN 1 END) AS nao_atendeu
FROM fila_com_retorno
GROUP BY vendedor
ORDER BY na_fila DESC, vendedor ASC;
