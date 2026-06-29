#!/usr/bin/env bash
# =====================================================================
# Despliega TODO el sistema en el clúster EKS.
# - Inyecta ECR_REGISTRY (derivado de STS) e IMAGE_TAG en los manifests
#   con envsubst (sustitución acotada a esas variables).
# - Crea el Secret de MySQL de forma segura (la contraseña nunca se
#   guarda en un archivo del repo).
#
# Requisitos: kubectl configurado contra el clúster, aws cli, envsubst.
# Uso:
#   export MYSQL_ROOT_PASSWORD=admin123
#   AWS_REGION=us-east-1 IMAGE_TAG=latest ./scripts/deploy.sh
# =====================================================================
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
: "${MYSQL_ROOT_PASSWORD:?Debes exportar MYSQL_ROOT_PASSWORD antes de desplegar}"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
export ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
export IMAGE_TAG MYSQL_ROOT_PASSWORD

echo "=================================================="
echo " Desplegando en namespace 'innovatech'"
echo "   ECR_REGISTRY = $ECR_REGISTRY"
echo "   IMAGE_TAG    = $IMAGE_TAG"
echo "=================================================="

MANIFESTS=(
  k8s/01-namespace.yaml
  k8s/02-mysql-secret.yaml
  k8s/03-mysql-deployment-svc.yaml
  k8s/04-backend-despachos-deployment-svc.yaml
  k8s/05-backend-ventas-deployment-svc.yaml
  k8s/06-frontend-deployment-svc.yaml
  k8s/07-backend-despachos-hpa.yaml
  k8s/08-backend-ventas-hpa.yaml
  k8s/09-frontend-hpa.yaml
)

for f in "${MANIFESTS[@]}"; do
  echo "[apply] $f"
  envsubst '${ECR_REGISTRY} ${IMAGE_TAG} ${MYSQL_ROOT_PASSWORD}' < "$f" | kubectl apply -f -
done

echo ""
echo "Esperando a que los Deployments estén disponibles..."
kubectl -n innovatech rollout status deployment/proyecto-db   --timeout=180s || true
kubectl -n innovatech rollout status deployment/api-despachos --timeout=300s
kubectl -n innovatech rollout status deployment/api-ventas    --timeout=300s
kubectl -n innovatech rollout status deployment/front-despacho --timeout=180s

echo ""
echo "Pods:"
kubectl -n innovatech get pods -o wide
echo ""
echo "URL pública del Frontend (el NLB puede tardar 1-3 min en quedar activo):"
kubectl -n innovatech get svc front-despacho \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}{"\n"}'
