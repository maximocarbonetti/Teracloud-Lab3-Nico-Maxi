# Runbook

Operación día a día y resolución de los problemas que ya nos encontramos.

## Comprobaciones rápidas de salud

| Qué mirar | Dónde |
|---|---|
| ¿El sitio responde por HTTPS? | `curl -I https://<app_fqdn>` → debe dar 200 |
| ¿HTTP redirige a HTTPS? | `curl -I http://<app_fqdn>` → debe dar 301 hacia `https://` |
| ¿Las tasks están corriendo? | ECS → cluster `lab3-dev-cluster` → servicios `lab3-dev-frontend` (2/2) y `lab3-dev-mysql` (1/1) |
| ¿Los targets están sanos? | EC2 → Target Groups → `lab3-dev-alb-frontend-tg` → healthy |
| ¿El frontend ve la base? | La home de la app muestra "Estado de la base de datos: OK" |
| Estado general | CloudWatch → Dashboards → `lab3-dev-health` |

## Logs

- Frontend: CloudWatch Logs, grupo `/ecs/lab3-dev-frontend`
- MySQL: CloudWatch Logs, grupo `/ecs/lab3-dev-mysql`
- Build: CloudWatch Logs, grupo del proyecto CodeBuild `lab3-dev-build`

## Desplegar una nueva versión de la app

Push a `main`. El pipeline (`lab3-dev-pipeline`) buildea, sube a ECR con el tag
del commit y actualiza el servicio ECS. Para forzar un despliegue sin cambios de
código, usar *Release change* en la consola de CodePipeline.

## Problemas conocidos y cómo resolverlos

### `Error acquiring the state lock` (StatusCode 412)

Quedó un lock huérfano, normalmente por haber cortado un `plan`/`apply` con
Ctrl+C. Tomar el `ID` que aparece en el mensaje y liberarlo:

```bash
terraform force-unlock <ID>
```

Antes de hacerlo, confirmar con la otra persona del equipo que no tenga un
apply corriendo de verdad.

### `ConfigurationException: ... service-linked role ... might not yet exist` (CodeStar Notifications)

La primera vez que se crea una notification rule en una cuenta AWS, el
service-linked role tarda hasta 15 minutos en existir. Opciones:

1. Esperar y volver a correr `terraform apply` (es lo que recomendamos).
2. Desbloquear el resto del apply poniendo
   `enable_pipeline_notifications = false` en `terraform.tfvars`, y volver a
   `true` más tarde.

### `InvalidChangeBatch: ... but it already exists` (Route53)

El registro ya existía en la zona, creado a mano antes de terraformarlo. El
módulo `dns` usa `allow_overwrite = true`, así que Terraform toma el control del
registro existente en lugar de fallar.

### `A records ... not supported when specifying 'host' or 'bridge' for networkMode`

Cloud Map sólo admite registros A cuando la task usa `awsvpc`. Por eso la task
de MySQL usa `awsvpc` (con su propia ENI en las subnets privadas) y no `bridge`.
El frontend sí usa `bridge`, porque necesita puertos dinámicos para registrarse
en el target group con `target_type = "instance"`.

### El servicio del frontend no levanta tasks

Causas habituales, en orden:

1. **La imagen no existe todavía en ECR.** Es lo esperable antes del primer
   push a `main`. Ver el pipeline.
2. **No hay capacidad en el cluster.** Revisar que el ASG tenga instancias
   `InService` y que estén registradas en el cluster ECS.
3. **Fallo al leer los secretos de SSM.** Revisar los eventos del servicio: si
   dice `ResourceInitializationError` con `ssm`, revisar la policy del execution
   role.

### La task de MySQL no arranca o pierde los datos

- Revisar en los eventos del servicio si falla el montaje del EFS. El access
  point usa autorización IAM: el task role de MySQL necesita
  `elasticfilesystem:ClientMount` y `ClientWrite` (ya está en el módulo).
- El security group del EFS sólo acepta NFS (2049) desde el security group de
  MySQL. Si se cambia el SG de la task, hay que actualizar esa regla.
- Los datos viven en el access point `/mysql` del filesystem, no en la
  instancia: si la task se reprograma en otra AZ, los datos siguen ahí.

## Destruir el entorno

```bash
cd lab3-iac/environments/dev
terraform destroy
```

El bucket del tfstate (creado por `bootstrap`) tiene `prevent_destroy = true` a
propósito y no se elimina con esto.
