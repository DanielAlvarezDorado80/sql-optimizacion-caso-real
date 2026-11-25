-- Esquema y datos de prueba deterministas: 200.000 clientes y 3.000.000 de pedidos (2024-2025)
DROP TABLE IF EXISTS pedidos;
DROP TABLE IF EXISTS clientes;

CREATE TABLE clientes (
    id         integer PRIMARY KEY,
    nombre     varchar(60)  NOT NULL,
    email      varchar(120) NOT NULL,
    provincia  varchar(30)  NOT NULL,
    alta       date         NOT NULL
);

CREATE TABLE pedidos (
    id          bigint PRIMARY KEY,
    cliente_id  integer       NOT NULL REFERENCES clientes (id),
    fecha       timestamp     NOT NULL,
    estado      varchar(12)   NOT NULL,
    importe     numeric(10,2) NOT NULL
);

SELECT setseed(0.42);

INSERT INTO clientes (id, nombre, email, provincia, alta)
SELECT g,
       'Cliente ' || g,
       'cliente' || g || '@ejemplo.es',
       (ARRAY['Madrid','Barcelona','Valencia','Sevilla','Zaragoza','Málaga','Murcia','Bizkaia',
              'Alicante','Cádiz','A Coruña','Asturias','León','Granada','Toledo','Navarra',
              'Badajoz','Cantabria','Valladolid','Girona'])[1 + (random() * 19)::int],
       date '2015-01-01' + (random() * 3650)::int
FROM generate_series(1, 200000) g;

INSERT INTO pedidos (id, cliente_id, fecha, estado, importe)
SELECT g,
       1 + (random() * 199999)::int,
       timestamp '2024-01-01' + random() * interval '730 days',
       CASE WHEN random() < 0.08 THEN 'CANCELADO'
            WHEN random() < 0.15 THEN 'PENDIENTE'
            ELSE 'ENTREGADO' END,
       round((5 + random() * 495)::numeric, 2)
FROM generate_series(1, 3000000) g;

ANALYZE clientes;
ANALYZE pedidos;
