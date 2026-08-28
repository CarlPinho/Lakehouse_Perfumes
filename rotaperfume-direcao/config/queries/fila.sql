-- @param vendedor STRING = Todos
WITH retorno_recente AS (
  SELECT
    cliente_id,
    status,
    comentario,
    registrado_em,
    registrado_por,
    ROW_NUMBER() OVER (PARTITION BY cliente_id ORDER BY registrado_em DESC) AS rn
  FROM lakehouse_rotaperfume.gold.retorno_ligacao
)
SELECT
  f.ordem,
  f.cliente_id,
  f.razao_social,
  f.cidade,
  f.uf,
  f.ticket_medio,
  f.vendedor,
  f.score,
  f.faixa,
  f.motivo,
  f.sugestao,
  r.status AS retorno_status,
  r.comentario AS retorno_comentario,
  r.registrado_em AS retorno_data
FROM lakehouse_rotaperfume.gold.fila_semanal f
LEFT JOIN retorno_recente r ON f.cliente_id = r.cliente_id AND r.rn = 1
WHERE (:vendedor = 'Todos' OR f.vendedor = :vendedor)
ORDER BY f.score DESC, f.ordem ASC;
