#!/usr/bin/env bash
# =====================================================================
# Generador de carga para gatillar el autoscaling (HPA) - IE3.
# Lanza un pod efímero que hace muchas peticiones en paralelo al
# backend, subiendo el uso de CPU hasta que el HPA agrega réplicas.
#
# Uso:
#   ./scripts/load-test.sh                                  # ataca despachos
#   TARGET=http://api-ventas:8080/api/v1/ventas ./scripts/load-test.sh
#   WORKERS=80 ./scripts/load-test.sh
#
# En OTRA terminal, observa el escalado en vivo:
#   kubectl -n innovatech get hpa -w
#   kubectl -n innovatech top pods
# =====================================================================
set -euo pipefail

NS="innovatech"
TARGET="${TARGET:-http://api-despachos:8080/api/v1/despachos}"
WORKERS="${WORKERS:-50}"

echo "Generando carga hacia : $TARGET"
echo "Workers en paralelo    : $WORKERS"
echo "Detén con Ctrl+C (el pod se elimina solo al salir)."
echo ""

kubectl -n "$NS" run load-generator \
  --image=busybox:1.36 --restart=Never --rm -it -- \
  /bin/sh -c 'i=0; while [ $i -lt '"$WORKERS"' ]; do ( while true; do wget -q -O- '"$TARGET"' >/dev/null 2>&1; done ) & i=$((i+1)); done; echo "Carga en curso con '"$WORKERS"' workers..."; wait'
