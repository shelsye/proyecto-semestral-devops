#!/usr/bin/env bash
# =====================================================================
# Crea los repositorios de Amazon ECR para las 3 imágenes (idempotente).
# Uso:  AWS_REGION=us-east-1 ./scripts/create-ecr.sh
# =====================================================================
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
REPOS=(despachos-backend ventas-backend frontend-despacho)

for repo in "${REPOS[@]}"; do
  if aws ecr describe-repositories --repository-names "$repo" --region "$AWS_REGION" >/dev/null 2>&1; then
    echo "[=] ECR repo '$repo' ya existe."
  else
    echo "[+] Creando ECR repo '$repo'..."
    aws ecr create-repository \
      --repository-name "$repo" \
      --region "$AWS_REGION" \
      --image-scanning-configuration scanOnPush=true \
      --image-tag-mutability MUTABLE >/dev/null
    echo "    -> creado."
  fi
done

echo "Repositorios ECR listos en la región $AWS_REGION."
