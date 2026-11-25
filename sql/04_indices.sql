-- Índices de la solución (sirven para los dos casos)

-- Clientes: filtro por provincia (y alta, en el caso 2). INCLUDE nombre para no ir a la tabla
CREATE INDEX IF NOT EXISTS ix_clientes_provincia_alta
    ON clientes (provincia, alta) INCLUDE (nombre);

-- Pedidos: por cliente y fecha descendente, cubriendo estado e importe.
--  · Caso 1: por cada cliente de Madrid, lee solo el rango de fechas de octubre
--  · Caso 2: por cada cliente, la primera entrada del índice ES su último pedido
-- Sustituye al índice simple sobre cliente_id, que pasa a ser redundante
CREATE INDEX IF NOT EXISTS ix_pedidos_cliente_fecha
    ON pedidos (cliente_id, fecha DESC) INCLUDE (estado, importe);
DROP INDEX IF EXISTS ix_pedidos_cliente;

-- VACUUM actualiza el mapa de visibilidad: necesario para los index-only scans
VACUUM ANALYZE clientes;
VACUUM ANALYZE pedidos;
