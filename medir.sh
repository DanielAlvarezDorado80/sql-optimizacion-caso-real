#!/usr/bin/env bash
# Ejecuta una consulta N veces con EXPLAIN (ANALYZE, BUFFERS), guarda el plan y devuelve la mediana.
# Uso: ./medir.sh <fichero.sql> <etiqueta> [repeticiones]
# Variables de conexión estándar de psql: PGHOST, PGPORT, PGDATABASE, PGUSER
set -euo pipefail
sql="$1"; etiqueta="$2"; n="${3:-7}"
mkdir -p resultados
consulta="$(grep -v '^\s*--' "$sql")"
psql -X -q -c "${consulta%;}" > /dev/null          # 1ª ejecución para calentar caché (se descarta)
tiempos=()
for i in $(seq "$n"); do
  plan="$(psql -X -qAt -c "EXPLAIN (ANALYZE, BUFFERS) ${consulta%;}")"
  tiempos+=("$(grep -oP 'Execution Time: \K[0-9.]+' <<< "$plan")")
done
echo "$plan" > "resultados/plan_${etiqueta}.txt"
mediana="$(printf '%s\n' "${tiempos[@]}" | sort -n | awk '{a[NR]=$1} END {print a[int((NR+1)/2)]}')"
echo "${etiqueta};${mediana}" | tee -a resultados/tiempos.csv
