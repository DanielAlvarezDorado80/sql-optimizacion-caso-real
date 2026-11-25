-- CASO 2 · Versión optimizada: LATERAL + LIMIT 1 apoyado en el índice (cliente_id, fecha DESC)
-- Por cada cliente se lee una sola entrada del índice, en vez de recorrer todos sus pedidos
SELECT c.id, c.nombre, u.fecha, u.importe
FROM clientes c
CROSS JOIN LATERAL (
    SELECT p.fecha, p.importe
    FROM pedidos p
    WHERE p.cliente_id = c.id
    ORDER BY p.fecha DESC
    LIMIT 1
) u
WHERE c.provincia = 'Girona'
  AND c.alta >= date '2024-01-01'
ORDER BY c.id;
