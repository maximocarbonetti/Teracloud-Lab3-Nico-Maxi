# Convenciones de naming, tagging y estilo del equipo

## Naming

Todos los recursos se nombran con el prefijo `<project_name>-<environment>`,
que en el código es `local.name_prefix` (en dev: `lab3-dev`).

| Recurso | Patrón | Ejemplo |
|---|---|---|
| VPC / subnets | `<prefix>-<tipo>-<az>` | `lab3-dev-public-us-east-1a` |
| Security group | `<prefix>-<rol>-sg` | `lab3-dev-alb-sg` |
| Cluster ECS | `<prefix>-cluster` | `lab3-dev-cluster` |
| Servicio ECS | `<prefix>-<servicio>` | `lab3-dev-frontend` |
| ALB | `<prefix>-alb` | `lab3-dev-alb` |
| Target group | `<alb>-<servicio>-tg` | `lab3-dev-alb-frontend-tg` |
| Repositorio ECR | `<prefix>-<servicio>` | `lab3-dev-frontend` |
| Log group | `/ecs/<prefix>-<servicio>` | `/ecs/lab3-dev-frontend` |
| Parámetros SSM | `/<project>/<env>/<dominio>/<clave>` | `/lab3/dev/db/password` |
| Bucket de estado | `<prefix>-tfstate` | `lab3-dev-tfstate` |

Los roles IAM y security groups usan `name_prefix` en lugar de `name`, para que
Terraform pueda reemplazarlos sin colisiones de nombre.

## Tagging

Todos los recursos llevan como mínimo:

```hcl
{
  Project     = var.project_name
  Environment = var.environment
  ManagedBy   = "terraform"
}
```

Definido una sola vez en `environments/dev/locals.tf` (`local.common_tags`) y
propagado a cada módulo por la variable `tags`. Los recursos con nombre visible
agregan además `Name`.

## Estilo de código

- `terraform fmt` antes de commitear.
- Un archivo por responsabilidad dentro de cada módulo: `main.tf` (recursos),
  `variables.tf` (inputs), `outputs.tf` (outputs), `versions.tf` (versiones).
- Toda variable lleva `description`. Las que no tienen default son obligatorias
  a propósito.
- Los módulos no hardcodean valores del entorno: todo lo que cambia entre
  entornos entra por variable.
- Los módulos no declaran `provider`: lo heredan del entorno que los llama.
- Comentarios en castellano, explicando el *por qué* de las decisiones no
  obvias (por ejemplo, por qué MySQL usa `awsvpc` y el frontend `bridge`).

## Git Flow

- `main` — rama estable. Es la que dispara el pipeline de CI/CD.
- `development` — integración. Es donde trabajamos día a día.
- `feature/<descripcion>` — para cambios más grandes o riesgosos, se mergean a
  `development`.

Antes de pushear a `development`: `git pull` siempre, para no pisar el trabajo
del otro.
