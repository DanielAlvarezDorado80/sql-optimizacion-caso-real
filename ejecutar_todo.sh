#!/usr/bin/env bash
# Reproduce el caso completo: datos -> mediciones "antes" -> índices -> mediciones "después".
# Requiere PostgreSQL 14+ y psql. Conexión con las variables estándar: PGHOST, PGPORT, PGDATABASE, PGUSER
set -euo pipefail
cd "$(dirname "$0")"
psql -X -q -v ON_ERROR_STOP=1 -f sql/01_esquema_y_datos.sql
psql -X -q -v ON_ERROR_STOP=1 -f sql/00_indice_inicial.sql
echo 'etiqueta;mediana_ms' > resultados/tiempos.csv
./medir.sh sql/02_caso1_lenta.sql caso1_antes
./medir.sh sql/05_caso2_lenta.sql caso2_antes 3
psql -X -q -v ON_ERROR_STOP=1 -f sql/04_indices.sql
./medir.sh sql/02_caso1_lenta.sql caso1_original_con_indices
./medir.sh sql/05_caso2_lenta.sql caso2_original_con_indices 3
./medir.sh sql/03_caso1_optimizada.sql caso1_despues
./medir.sh sql/06_caso2_optimizada.sql caso2_despues
