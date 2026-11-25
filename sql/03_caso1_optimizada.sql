-- CASO 1 · Versión optimizada
--  1) Rango de fechas en lugar de to_char(): el índice sobre fecha ya se puede usar
--  2) Comparación directa con provincia (el dato ya se guarda normalizado)
-- Requiere los índices de 04_indices.sql
SELECT c.id, c.nombre, COUNT(*) AS pedidos, SUM(p.importe) AS total
FROM pedidos p
JOIN clientes c ON c.id = p.cliente_id
WHERE p.fecha >= timestamp '2025-10-01'
  AND p.fecha <  timestamp '2025-11-01'
  AND c.provincia = 'Madrid'
  AND p.estado <> 'CANCELADO'
GROUP BY c.id, c.nombre
ORDER BY total DESC
LIMIT 50;
