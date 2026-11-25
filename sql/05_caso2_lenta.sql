-- CASO 2 · Último pedido de cada cliente de Girona dado de alta en 2024
-- Versión original: subconsulta correlacionada con MAX() por cada fila de pedidos
SELECT c.id, c.nombre, p.fecha, p.importe
FROM clientes c
JOIN pedidos p ON p.cliente_id = c.id
WHERE c.provincia = 'Girona'
  AND c.alta >= date '2024-01-01'
  AND p.fecha = (SELECT MAX(p2.fecha) FROM pedidos p2 WHERE p2.cliente_id = c.id)
ORDER BY c.id;
