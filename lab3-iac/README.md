# Lab3 — Infraestructura como Código (Terraform)

Infraestructura reproducible para una arquitectura de alta disponibilidad en
AWS: **ECS (EC2 launch type) + ALB con HTTPS + MySQL con almacenamiento
persistente en EFS**, con pipeline de CI/CD, parámetros en SSM, alarmas de
CloudWatch y notificaciones por email.

## Arquitectura

```
Internet
   │
   ▼
Route53 (alb.maxicarbonetti.ownboarding.teratest.net)
   │
   ▼
ALB (subnets públicas) ── listener :80 ─── redirect 301 ──▶ listener :443 (cert ACM)
                                                                  │
                                                          target group (instance)
                                                                  │
                                    ┌─────────────────────────────▼──────────────────────────┐
                                    │  ECS Cluster (EC2 launch type, subnets privadas)       │
                                    │                                                        │
                                    │  Service frontend  → 2 tasks PHP (bridge, puerto       │
                                    │                      dinámico), env vars desde SSM     │
                                    │                                                        │
                                    │  Service mysql     → 1 task MySQL (awsvpc + Cloud Map) │
                                    │                      volumen persistente en EFS        │
                                    └────────────────────────────────────────────────────────┘
                                                          │
                                                          ▼
                                                 EFS (mount target por AZ)
```

Ver también el diagrama de la solución en la documentación de la entrega.

## Estructura del repositorio

```
lab3-iac/
├── bootstrap/          Bucket S3 del tfstate (se corre UNA vez, con estado local)
├── environments/
│   └── dev/            Punto de entrada real: instancia todos los módulos
└── modules/            Módulos reutilizables (ver docs/decisiones-modulos.md)
    ├── network/            VPC, subnets, NAT, route tables
    ├── security-groups/    ALB → frontend → mysql → efs
    ├── ecs-cluster/        Cluster ECS + ASG + capacity provider
    ├── ecs-service/        Tasks y services de frontend y mysql
    ├── alb/                ALB, listeners (80→443) y target group
    ├── acm/                Certificado TLS + validación DNS
    ├── dns/                Hosted zone + registro alias al ALB
    ├── efs/                Filesystem, mount targets y access point
    ├── ecr/                Repositorio de imágenes + lifecycle policy
    ├── ssm-parameters/     Config de conexión a la DB
    ├── cicd/               CodePipeline + CodeBuild + notificación
    ├── observability/      Alarmas CloudWatch + dashboard
    └── notifications/      Topic SNS + suscripciones por email
```

`lab3-app/` (fuera de esta carpeta) contiene la aplicación PHP y su
`Dockerfile`/`buildspec.yml`, que es lo que buildea el pipeline.

## Estado remoto

El estado vive en un bucket S3 con **lock nativo de S3** (`use_lockfile = true`),
sin tabla de DynamoDB. Requiere Terraform >= 1.10 y versioning habilitado en el
bucket (ambos configurados).

## Cómo desplegar desde cero

### 1. Bootstrap (una sola vez)

```bash
cd lab3-iac/bootstrap
terraform init
terraform apply
```

Crea el bucket del tfstate. El output `backend_config_snippet` da el bloque
listo para `environments/dev/backend.tf`.

### 2. Entorno dev

```bash
cd ../environments/dev
cp terraform.tfvars.example terraform.tfvars   # completar valores reales
terraform init
terraform plan
terraform apply
```

Valores a completar en `terraform.tfvars`: `domain_zone_name`,
`app_record_name`, `db_password`, `github_repository_id` y
`notification_emails`. **`terraform.tfvars` no se versiona** (está en
`.gitignore`) porque contiene la password de la base.

### 3. Pasos manuales posteriores al apply

Son las únicas dos acciones de consola de todo el proyecto, y no se pueden
automatizar por API:

1. **Autorizar la conexión a GitHub**: la `aws_codestarconnections_connection`
   se crea en estado `PENDING`. Ir a *Developer Tools → Settings → Connections*
   en la consola de AWS y completar el OAuth con GitHub. El ARN sale del output
   `codestar_connection_arn`.
2. **Confirmar las suscripciones de SNS**: cada dirección en
   `notification_emails` recibe un mail de confirmación que hay que aceptar.

### 4. Primer despliegue de la aplicación

El servicio del frontend arranca apuntando a `<repo_ecr>:latest`, que todavía
no existe en ECR. Al hacer push a la rama `main`, el pipeline buildea la imagen,
la sube a ECR y actualiza el servicio ECS. A partir de ahí el ciclo es
automático.

## Outputs útiles

```bash
terraform output
```

- `alb_dns_name` — URL pública del ALB
- `app_fqdn` — FQDN de la aplicación (HTTPS)
- `ecr_repository_url` — repositorio de imágenes
- `dashboard_name` — dashboard de CloudWatch
- `codestar_connection_arn` / `codestar_connection_status`

## Convenciones

Ver `CONVENCIONES.md` (naming y tagging) y `docs/runbook.md` (operación y
resolución de problemas conocidos).
