# Config del backend S3 remoto para dev (bucket, key, lock nativo)
#
# El bucket lo crea lab3-iac/bootstrap (que corre con estado local, una sola
# vez). use_lockfile activa el lock nativo de S3 (conditional writes): no hay
# tabla de DynamoDB en ningun lado del proyecto.

terraform {
  backend "s3" {
    bucket       = "lab3-dev-tfstate"
    key          = "dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
