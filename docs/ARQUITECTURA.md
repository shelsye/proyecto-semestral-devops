# Documento de Arquitectura y Defensa Técnica — EP3 DevOps

Material de apoyo para la **presentación individual**. Explica la arquitectura final, las decisiones tomadas y su justificación, los problemas encontrados y cómo se resolvieron.

---

## 1. Arquitectura final

La aplicación de **Innovatech Chile** (gestión de despachos y ventas) se ejecuta sobre **Amazon EKS** como 3 microservicios contenerizados + base de datos, en el namespace `innovatech`.

```
                          Internet
                             │  HTTP :80
                             ▼
                ┌────────────────────────────┐
                │  AWS Network Load Balancer  │  (Service type LoadBalancer)
                └────────────┬───────────────┘
                             ▼
        ┌──────────────────────────────────────────┐
        │   Deployment front-despacho (2–5 pods)    │  React + Nginx
        │   Nginx = reverse proxy + SPA              │
        └───────┬───────────────────────┬───────────┘
        /api/v1/ventas            /api/* (despachos)
                │                         │
                ▼                         ▼
      ┌──────────────────┐      ┌──────────────────┐
      │ Service api-ventas│      │Service api-despachos│   (ClusterIP, internos)
      │  (2–5 pods)       │      │  (2–5 pods)       │
      └─────────┬─────────┘      └─────────┬────────┘
                │                          │
                └────────────┬─────────────┘
                             ▼
                   ┌───────────────────┐
                   │  Service db (MySQL) │  ClusterIP
                   │  ventas_db / despacho_db
                   └───────────────────┘

   Amazon ECR  ── pull imágenes ──► nodos EKS
   GitHub Actions ── build/push ──► ECR ── kubectl apply ──► EKS
```

**Puntos clave:**
- **Único punto de entrada público:** el frontend (vía NLB). Los backends y la BD son `ClusterIP` (solo accesibles dentro del clúster) → menor superficie de ataque.
- **Comunicación Front → Back por proxy inverso:** el navegador llama a `/api/...` (mismo origen) y Nginx reenvía al microservicio interno por DNS de Kubernetes. Evita CORS y no expone los backends.
- **Cada microservicio escala de forma independiente** mediante su propio HPA.

---

## 2. Decisiones de arquitectura y justificación

| Decisión | Alternativa | Por qué se eligió |
|---|---|---|
| **EKS (Kubernetes)** | ECS Fargate | Estándar de orquestación portable (no atado a AWS), control fino de scheduling, HPA, self-healing y manifests declarativos. El proyecto ya partía con manifests K8s. |
| **Proxy inverso en Nginx** (frontend → backends) | Exponer cada backend con su LB | Un solo LB público (menor costo y superficie), sin CORS, y el frontend habla a "su propio origen". Patrón BFF/edge clásico. |
| **NLB (`type: LoadBalancer`)** | ALB + Ingress Controller | El NLB in-tree de EKS **no requiere instalar el AWS Load Balancer Controller**, lo que simplifica el despliegue en Learner Lab. (El ALB+Ingress sería el paso siguiente para enrutado L7.) |
| **MySQL como pod (ClusterIP)** | Amazon RDS | Más simple y sin costo extra para la demo. *Trade-off:* almacenamiento efímero (mitigable con un PVC sobre EBS). En producción se usaría RDS. |
| **Una instancia MySQL, 2 bases lógicas** (`despacho_db`, `ventas_db`) | Una BD por microservicio (instancias separadas) | Aísla los datos por servicio (cada backend ve solo su esquema) sin el costo de dos motores. `createDatabaseIfNotExist=true` las autocrea. |
| **Imágenes parametrizadas** (`${ECR_REGISTRY}/${IMAGE_TAG}`) | URL de imagen fija | El registry se deriva de la cuenta en runtime (STS) → el repo no contiene IDs de cuenta y funciona aunque la cuenta del lab cambie. |
| **Sin `imagePullSecrets`** | Secret docker-registry | En EKS los nodos se autentican a ECR vía su rol IAM (`LabRole`), que ya tiene permiso de lectura. Menos configuración y menos secretos. |

---

## 3. Roles IAM

En **AWS Academy Learner Lab no se pueden crear roles IAM nuevos**, por lo que se reutiliza el rol preexistente **`LabRole`**:

| Uso | Rol | Permisos relevantes |
|---|---|---|
| Plano de control de EKS (`serviceRoleARN`) | `LabRole` | Gestión del clúster EKS |
| Nodos / Nodegroup (`instanceRoleARN`) | `LabRole` | `AmazonEKSWorkerNodePolicy`, CNI, y **lectura de ECR** (permite el `docker pull` sin secrets) |
| Pipeline CI/CD | Credenciales temporales de AWS Academy (GitHub Secrets) | `ecr:*` para push, `eks:*` para desplegar |

> Definido en `infra/eksctl-cluster.yaml`. En un entorno productivo se usarían roles con **privilegio mínimo** y separados por función (execution role, node role, task role), en lugar de un rol único.

---

## 4. Redes (VPC, subredes, Security Groups)

`eksctl` provisiona automáticamente la capa de red al crear el clúster:

- **VPC dedicada** para el clúster.
- **Subredes públicas y privadas** repartidas en múltiples *Availability Zones* (alta disponibilidad).
- **Security Groups** que permiten el tráfico entre el plano de control y los nodos, y el tráfico del NLB hacia los pods del frontend.
- El **NLB** se crea automáticamente al desplegar el `Service type: LoadBalancer` del frontend y se ubica en las subredes públicas.

La comunicación **interna** entre microservicios usa los nombres de `Service` (DNS de Kubernetes vía CoreDNS): `api-despachos`, `api-ventas`, `db`.

---

## 5. Autoscaling (IE3)

**Mecanismo:** Horizontal Pod Autoscaler (HPA) `autoscaling/v2`, basado en CPU, alimentado por **metrics-server**.

| Servicio | Min | Max | Umbral CPU | Justificación del umbral |
|---|---|---|---|---|
| `front-despacho` | 2 | 5 | **50 %** | Es el punto de entrada público; conviene que reaccione antes ante tráfico. |
| `api-despachos` | 2 | 5 | **60 %** | Carga de negocio; 60 % aprovecha mejor cada pod antes de escalar, evitando réplicas innecesarias. |
| `api-ventas` | 2 | 5 | **60 %** | Mismo criterio que despachos. |

**`minReplicas: 2`** garantiza alta disponibilidad (si un pod cae, sigue habiendo servicio) y `maxReplicas: 5` acota el consumo de recursos del laboratorio.

**Requisito:** cada Deployment define `resources.requests.cpu`, sin el cual el HPA no puede calcular el porcentaje de uso.

**Evidencia:** `scripts/load-test.sh` genera carga y con `kubectl get hpa -w` se observa el escalado de 2→5 réplicas y el posterior *scale-down* al cesar la carga.

---

## 6. Pipeline CI/CD (IE4)

Workflow `.github/workflows/ci-cd-eks.yml`, disparado por `push` a `main`/`master`:

```
checkout → credenciales AWS → login ECR → buildx
   → build & push (despachos, ventas, frontend)  [tag = SHA del commit]
   → update-kubeconfig → crear/actualizar Secret → kubectl apply (envsubst)
   → rollout status → URL pública
```

**Características de calidad:**
- **Trazabilidad:** cada imagen se etiqueta con el SHA corto del commit (se sabe exactamente qué versión está corriendo).
- **Sin credenciales en el código:** AWS via GitHub Secrets; registry de ECR derivado por STS.
- **Despliegue progresivo:** `kubectl rollout` aplica *rolling updates* sin downtime y permite `rollout undo` ante fallos.
- **Caché de capas Docker** (`type=gha`) para acelerar builds sucesivos.

**Métricas a comentar en la defensa** (pestaña *Actions* de GitHub): duración total del pipeline, tiempo por etapa (build vs push vs deploy), tasa de éxito/fallo y logs por paso.

---

## 7. Problemas encontrados y cómo se resolvieron

> Esta sección documenta el trabajo real de depuración (excelente material para la defensa).

| # | Problema detectado | Causa | Solución aplicada |
|---|---|---|---|
| 1 | El frontend no alcanzaba al backend en K8s | `nginx.conf` apuntaba a `api_despachos` (nombre de docker-compose, con guion bajo), pero el `Service` de K8s es `api-despachos` (con guion) | Se corrigió el `proxy_pass` al nombre correcto del Service |
| 2 | Las llamadas a la API daban **404** | El `proxy_pass` con `/` final **borraba** el prefijo `/api`, pero los controladores Spring usan `@RequestMapping("api/v1/...")` | Se quitó el `/` final para **conservar** el prefijo `/api`; el proxy de Vite se alineó (sin `rewrite`) |
| 3 | La tabla de Ventas apuntaba a una **IP fija** (`http://3.220.144.137:8080`) | Endpoint hardcodeado de una EC2 antigua (EP2) | Se reemplazó por la ruta relativa `/api` vía proxy de Nginx (`import.meta.env.VITE_API_BASE || "/api"`) |
| 4 | Imágenes con **IDs de cuenta hardcodeados** e inconsistentes (`tienda-*`, dos cuentas distintas) | Plantillas de ejemplo sin parametrizar | Imágenes parametrizadas `${ECR_REGISTRY}/${IMAGE_TAG}`; el registry se deriva por STS |
| 5 | El backend de **Ventas no estaba en Kubernetes** ni tenía health check | Solo se había contemplado Despachos | Se añadieron `Deployment`, `Service` y `HPA` de Ventas, y un endpoint `/api/v1/ventas/health` para las *probes* |
| 6 | `imagePullSecrets` referenciaba un secret inexistente | Patrón de otro entorno | Se eliminó: en EKS los nodos leen ECR vía su rol IAM (`LabRole`) |
| 7 | El secret de BD se versionaba en base64 | `data: root-password: YWRtaW4xMjM=` (base64 ≠ cifrado) | El valor real ya **no se versiona**; se inyecta en el despliegue (envsubst / `kubectl create secret` desde GitHub Secret) |
| 8 | El pipeline original desplegaba a **ECS** y solo el frontend | Workflow heredado de otra arquitectura | Reescrito para **EKS** cubriendo los 3 servicios (build → push → deploy) |

---

## 8. Posibles preguntas de defensa (y respuestas)

- **¿Por qué EKS y no ECS?** Portabilidad (Kubernetes estándar), self-healing declarativo, HPA y ecosistema. *Trade-off:* mayor complejidad y costo del plano de control.
- **¿Cómo se comunica el frontend con el backend sin exponerlo?** Nginx hace de reverse proxy hacia los `Service` internos (ClusterIP) por DNS de Kubernetes; el navegador solo ve `/api`.
- **¿Qué pasa si se cae un pod?** El `Deployment` mantiene el número de réplicas: Kubernetes recrea el pod (self-healing). Con `minReplicas: 2` siempre hay otra réplica sirviendo.
- **¿Cómo escala ante carga?** El HPA lee CPU desde metrics-server y agrega réplicas (hasta 5) al superar el umbral; al bajar la carga, reduce.
- **¿Dónde están las credenciales?** En Secrets de Kubernetes (BD) y GitHub Secrets (AWS); nunca en el repositorio.
- **¿Cómo se garantiza un deploy sin downtime?** `kubectl rollout` hace *rolling update*; si falla, `kubectl rollout undo`.
- **¿Persisten los datos?** Hoy la BD es efímera (demo). Para persistencia real se añade un PVC sobre EBS o se migra a RDS.
