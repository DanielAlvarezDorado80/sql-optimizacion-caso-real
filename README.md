# Optimización SQL: dos casos reales medidos con `EXPLAIN ANALYZE`

Dos consultas lentas típicas de un sistema de pedidos, su plan de ejecución, la causa, la solución y **la mejora medida**. Todo es reproducible con un script: datos deterministas de **3.000.000 de pedidos** y **200.000 clientes**.

| Caso | Antes | Después | Mejora | Bloques leídos |
|---|---:|---:|---:|---|
| 1 · Informe mensual por provincia | 137,3 ms | **24,8 ms** | **5,5×** | 95.847 → 17.650 |
| 2 · Último pedido de cada cliente | 776,2 ms | **3,3 ms** | **233×** | 48.251 + 12.833 temporales en disco → 2.013 |

Cada tiempo es la mediana de varias ejecuciones con la caché caliente, en PostgreSQL 16 con la ejecución en paralelo desactivada para que la comparación sea limpia. Los planes completos están en [`resultados/`](resultados/). Las versiones lenta y optimizada devuelven **exactamente las mismas filas**; se comprobó comparando un hash de la salida.

---

## Caso 1 · Informe mensual: ventas de octubre por cliente de Madrid

**Consulta original** ([`02_caso1_lenta.sql`](sql/02_caso1_lenta.sql)):

```sql
WHERE to_char(p.fecha, 'YYYY-MM') = '2025-10'
  AND upper(c.provincia) = 'MADRID'
```

**Qué muestra el plan** ([`plan_caso1_antes.txt`](resultados/plan_caso1_antes.txt)):
- `Seq Scan on clientes` con `upper(provincia)`: recorre los 200.000 clientes porque una función sobre la columna impide usar índices.
- El optimizador **estima 1.000 clientes y salen 5.211**: no tiene estadísticas de `upper(provincia)`.
- Por cada cliente lee **todos** sus pedidos y descarta el 93 % (`Rows Removed by Filter: 14` de cada 15) aplicando `to_char()` fila a fila.

**Solución** ([`03_caso1_optimizada.sql`](sql/03_caso1_optimizada.sql) + [`04_indices.sql`](sql/04_indices.sql)):

```sql
WHERE p.fecha >= timestamp '2025-10-01'
  AND p.fecha <  timestamp '2025-11-01'      -- rango: predicado "sargable"
  AND c.provincia = 'Madrid'                  -- el dato ya se guarda normalizado

CREATE INDEX ix_clientes_provincia_alta ON clientes (provincia, alta) INCLUDE (nombre);
CREATE INDEX ix_pedidos_cliente_fecha  ON pedidos (cliente_id, fecha DESC) INCLUDE (estado, importe);
```

El plan nuevo usa un `Index Only Scan` por cliente que lee **solo el rango de octubre**, sin tocar la tabla.

**¿Qué aporta cada parte?** Se midió la consulta original con los índices nuevos:

| Variante | Tiempo |
|---|---:|
| Original, índice simple por `cliente_id` | 137,3 ms |
| Original + índices nuevos | 74,0 ms |
| **Reescrita + índices nuevos** | **24,8 ms** |

Los índices reducen la lectura a la quinta parte, pero mientras quede `to_char()` en el `WHERE` se sigue calculando para cada fila. Además, el optimizador sigue estimando mal. **Hacen falta las dos cosas.**

---

## Caso 2 · Último pedido de cada cliente

**Consulta original** ([`05_caso2_lenta.sql`](sql/05_caso2_lenta.sql)): subconsulta correlacionada con `MAX()`.

```sql
AND p.fecha = (SELECT MAX(p2.fecha) FROM pedidos p2 WHERE p2.cliente_id = c.id)
```

**Qué muestra el plan** ([`plan_caso2_antes.txt`](resultados/plan_caso2_antes.txt)):
- `Seq Scan on pedidos` de **3.000.000 de filas** para construir un hash join de 8 *batches* que **se desborda a disco** (`temp written=12833`), solo para quedarse con 513 filas.
- La subconsulta se ejecuta 1.026 veces y cada una relee todos los pedidos del cliente.

**Solución** ([`06_caso2_optimizada.sql`](sql/06_caso2_optimizada.sql)): `LATERAL … ORDER BY fecha DESC LIMIT 1` apoyado en el índice `(cliente_id, fecha DESC)`. Por cada cliente se lee **una sola entrada del índice**: su último pedido.

**Aquí el índice es lo decisivo:** la consulta original con el índice nuevo ya baja a 4,0 ms. La versión `LATERAL` la deja en 3,3 ms y con menos lecturas (3.553 → 2.013 bloques), y además expresa la intención («el último pedido») sin depender de que no haya dos pedidos con la misma fecha.

---

## Lecciones

1. **Nada de funciones sobre columnas filtradas** (`to_char`, `upper`, `trunc`…): impiden usar índices y engañan al optimizador. Mejor rangos o un índice por expresión.
2. **Un índice bien diseñado sustituye a varios**: `(cliente_id, fecha DESC) INCLUDE (...)` resuelve los dos casos y deja redundante el índice simple sobre `cliente_id`.
3. **Medir siempre, y por separado**, el efecto del índice y el de la reescritura. En el caso 1 hacían falta las dos cosas; en el caso 2 bastaba casi con el índice.
4. **Mirar los bloques leídos y las estimaciones frente a las filas reales**, no solo el tiempo.

## Equivalencia en Oracle

Los dos antipatrones y sus soluciones son los mismos en Oracle:

| PostgreSQL | Oracle |
|---|---|
| `EXPLAIN (ANALYZE, BUFFERS)` | hint `/*+ GATHER_PLAN_STATISTICS */` + `DBMS_XPLAN.DISPLAY_CURSOR(format => 'ALLSTATS LAST')` |
| `to_char(fecha,'YYYY-MM') = …` → rango | igual: rango `fecha >= DATE '2025-10-01' AND fecha < DATE '2025-11-01'` (evitar `TRUNC(fecha)`, o crear un índice basado en función) |
| `INCLUDE (estado, importe)` | se añaden como columnas finales del índice compuesto |
| `CROSS JOIN LATERAL (… LIMIT 1)` | `CROSS APPLY (… FETCH FIRST 1 ROW ONLY)` (12c+) o `ROW_NUMBER() OVER (PARTITION BY cliente_id ORDER BY fecha DESC)` |
| `VACUUM ANALYZE` | `DBMS_STATS.GATHER_TABLE_STATS` |

## Reproducirlo

```bash
createdb optimizacion
export PGDATABASE=optimizacion
./ejecutar_todo.sh      # unos 2 minutos: genera datos, mide antes, crea índices, mide después
cat resultados/tiempos.csv
```

Los tiempos absolutos dependen de la máquina; las proporciones y los planes deberían ser muy parecidos.
