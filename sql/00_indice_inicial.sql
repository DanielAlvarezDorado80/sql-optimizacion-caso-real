-- Situación de partida: además de las PK, existe el índice "típico" sobre la clave foránea
CREATE INDEX IF NOT EXISTS ix_pedidos_cliente ON pedidos (cliente_id);
ANALYZE pedidos;
