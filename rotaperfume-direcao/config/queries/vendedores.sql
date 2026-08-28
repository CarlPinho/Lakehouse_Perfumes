SELECT
  vendedor,
  COUNT(*) AS contatos
FROM lakehouse_rotaperfume.gold.fila_semanal
GROUP BY vendedor
ORDER BY contatos DESC, vendedor ASC;
