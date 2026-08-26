# Bucket S3 + configuracion de lock nativo para el backend remoto
#
# Este bootstrap se corre UNA SOLA VEZ, con estado local, antes de poder
# usar el backend remoto en environments/*. Crea el bucket S3 que va a
# guardar el tfstate y habilita el lock nativo de S3 (conditional writes,
# sin DynamoDB) para los backends que apunten a él.

terraform {
  required_version = ">= 1.10.0" # requerido por el lock nativo (use_lockfile)

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  bucket_name = "${var.project_name}-${var.environment}-tfstate"

  tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Layer       = "bootstrap"
    },
    var.extra_tags
  )
}

# -----------------------------------------------------------------------------
# Bucket S3 para el tfstate remoto
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "tfstate" {
  bucket = local.bucket_name

  lifecycle {
    prevent_destroy = true
  }

  tags = local.tags
}

# El lock nativo de S3 (conditional writes) requiere versioning habilitado
# en el bucket.
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Fuerza TLS en todas las requests al bucket
data "aws_iam_policy_document" "force_tls" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.tfstate.arn,
      "${aws_s3_bucket.tfstate.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  policy = data.aws_iam_policy_document.force_tls.json
}

# Nota: no se crea tabla de DynamoDB. El lock nativo de S3 (use_lockfile = true
# en el bloque backend "s3" de environments/dev) reemplaza al locking basado
# en DynamoDB y usa el propio bucket.
