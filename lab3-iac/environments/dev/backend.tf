# Config del backend S3 remoto para dev (bucket, key, lock nativo)
#
# Reemplazá el "bucket" por el valor de "tfstate_bucket_name" que te dio
# el output del bootstrap (lab3-iac/bootstrap), y corré `terraform init`
# en este directorio.

terraform {
  backend "s3" {
    bucket       = "lab3-dev-tfstate" # <- reemplazar por el bucket real del bootstrap
    key          = "dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true # lock nativo de S3, no requiere DynamoDB
  }
}
