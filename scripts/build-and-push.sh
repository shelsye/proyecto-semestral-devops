#!/usr/bin/env bash
# =====================================================================
# Construye y sube las 3 imágenes a Amazon ECR.
# El registry se deriva automáticamente de la cuenta AWS activa (STS),
# por lo que NO hay IDs de cuenta hardcodeados.
#
# Uso:
#   AWS_REGION=us-east-1 IMAGE_TAG=latest ./scripts/build-and-push.sh
# =====================================================================
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo "==> Login en ECR: ${ECR_REGISTRY}"
aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$ECR_REGISTRY"

build_push() {
  local name="$1" context="$2"
  echo "==> Construyendo imagen '${name}:${IMAGE_TAG}' desde ${context}"
  docker build -t "${ECR_REGISTRY}/${name}:${IMAGE_TAG}" "$context"
  docker push "${ECR_REGISTRY}/${name}:${IMAGE_TAG}"
  echo "    -> subida: ${ECR_REGISTRY}/${name}:${IMAGE_TAG}"
}

build_push despachos-backend ./back-Despachos_SpringBoot/Springboot-API-REST-DESPACHO
build_push ventas-backend    ./back-Ventas_SpringBoot/Springboot-API-REST
build_push frontend-despacho ./front_despacho

echo "Listo. Las 3 imágenes se subieron a ECR con el tag '${IMAGE_TAG}'."
