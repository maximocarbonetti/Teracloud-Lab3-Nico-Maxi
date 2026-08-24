# Como correr el bootstrap una sola vez antes de environments/dev

Este paso crea el bucket S3 que va a guardar el `tfstate` remoto de
`environments/dev` (y de cualquier otro entorno que agreguen), con el
**lock nativo de S3** habilitado (sin DynamoDB).

Requisitos: Terraform >= 1.10 y credenciales de AWS configuradas.

## Pasos

```bash
cd lab3-iac/bootstrap

# 1. Inicializar con estado local (todavia no hay backend remoto)
terraform init

# 2. Revisar y aplicar
terraform plan
terraform apply
```

Al terminar, el output `backend_config_snippet` te da el bloque listo
para pegar en `environments/dev/backend.tf`.

## Despues de aplicar

1. Copiá el `backend_config_snippet` del output a `environments/dev/backend.tf`.
2. Andá a `environments/dev` y corré `terraform init` para migrar (o
   inicializar) el estado contra el bucket remoto.

## Notas sobre el lock nativo

- `use_lockfile = true` usa "conditional writes" de S3 para el locking,
  sin necesitar una tabla de DynamoDB.
- Requiere que el bucket tenga **versioning habilitado** (ya lo configura
  este bootstrap).
- Requiere Terraform >= 1.10 tanto acá como en los entornos que usen este
  bucket como backend.
- El estado de ESTE bootstrap queda local (o podés migrarlo aparte a su
  propio backend si preferís no tenerlo local); no lo apunten al mismo
  bucket que crean, para evitar dependencias circulares.
