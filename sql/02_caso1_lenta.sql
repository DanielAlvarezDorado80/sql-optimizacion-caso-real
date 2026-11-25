-- CASO 1 · Informe mensual: ventas de octubre de 2025 por cliente de Madrid (sin cancelados)
-- Versión original: funciones sobre columnas en el WHERE (predicados no "sargables")
SELECT c.id, c.nombre, COUNT(*) AS pedidos, SUM(p.importe) AS total
FROM pedidos p
JOIN clientes c ON c.id = p.cliente_id
WHERE to_char(p.fecha, 'YYYY-MM') = '2025-10'
  AND upper(c.provincia) = 'MADRID'
  AND p.estado <> 'CANCELADO'
GROUP BY c.id, c.nombre
ORDER BY total DESC
LIMIT 50;
