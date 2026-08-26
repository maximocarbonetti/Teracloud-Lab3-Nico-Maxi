# Recursos del modulo cicd

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# -----------------------------------------------------------------------------
# Conexion a GitHub (CodeStar Connections)
#
# IMPORTANTE: Terraform crea la conexion pero queda en estado "PENDING".
# Hay que ir una vez a la consola de AWS (Developer Tools > Connections) y
# autorizarla contra la cuenta de GitHub - es la unica excepcion manual que
# permite el enunciado, porque el OAuth no se puede hacer por API.
# -----------------------------------------------------------------------------
resource "aws_codestarconnections_connection" "github" {
  name          = "${var.name_prefix}-github"
  provider_type = "GitHub"
  tags          = var.tags
}

# -----------------------------------------------------------------------------
# Bucket S3 para los artifacts del pipeline
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "artifacts" {
  bucket        = "${var.name_prefix}-pipeline-artifacts-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
  tags          = var.tags
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -----------------------------------------------------------------------------
# IAM - CodeBuild
# -----------------------------------------------------------------------------
data "aws_iam_policy_document" "codebuild_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codebuild" {
  name_prefix        = "${var.name_prefix}-codebuild-"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "codebuild_policy" {
  statement {
    effect    = "Allow"
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:GetObjectVersion", "s3:PutObject"]
    resources = ["${aws_s3_bucket.artifacts.arn}/*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
    ]
    resources = [var.ecr_repository_arn]
  }
}

resource "aws_iam_role_policy" "codebuild" {
  name   = "${var.name_prefix}-codebuild-policy"
  role   = aws_iam_role.codebuild.id
  policy = data.aws_iam_policy_document.codebuild_policy.json
}

# -----------------------------------------------------------------------------
# CodeBuild - build de la imagen Docker + push a ECR
# -----------------------------------------------------------------------------
resource "aws_codebuild_project" "this" {
  name          = "${var.name_prefix}-build"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 15
  tags          = var.tags

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true # necesario para "docker build" adentro de CodeBuild

    # Variables de entorno para la config del registry ECR (requerimiento del DoD)
    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = data.aws_region.current.name
    }

    environment_variable {
      name  = "REPOSITORY_URI"
      value = var.ecr_repository_url
    }

    environment_variable {
      name  = "CONTAINER_NAME"
      value = var.container_name
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = var.buildspec_path
  }
}

# -----------------------------------------------------------------------------
# IAM - CodePipeline
# -----------------------------------------------------------------------------
data "aws_iam_policy_document" "codepipeline_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codepipeline" {
  name_prefix        = "${var.name_prefix}-codepipeline-"
  assume_role_policy = data.aws_iam_policy_document.codepipeline_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "codepipeline_policy" {
  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:GetObjectVersion", "s3:PutObject", "s3:GetBucketVersioning"]
    resources = [aws_s3_bucket.artifacts.arn, "${aws_s3_bucket.artifacts.arn}/*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["codestar-connections:UseConnection"]
    resources = [aws_codestarconnections_connection.github.arn]
  }

  statement {
    effect    = "Allow"
    actions   = ["codebuild:BatchGetBuilds", "codebuild:StartBuild"]
    resources = [aws_codebuild_project.this.arn]
  }

  # Permisos que la accion de deploy a ECS de CodePipeline necesita. Ojo con
  # ecs:TagResource: hace falta porque nuestras task definitions llevan tags y
  # la accion re-registra la task definition con la imagen nueva. Sin el, el
  # deploy falla con "The provided role does not have sufficient permissions
  # to access ECS".
  statement {
    effect = "Allow"
    actions = [
      "ecs:DescribeClusters",
      "ecs:DescribeServices",
      "ecs:DescribeTaskDefinition",
      "ecs:DescribeTasks",
      "ecs:ListServices",
      "ecs:ListTaskDefinitions",
      "ecs:ListTasks",
      "ecs:RegisterTaskDefinition",
      "ecs:TagResource",
      "ecs:UpdateService",
    ]
    resources = ["*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = ["*"]
    condition {
      test     = "StringEqualsIfExists"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "codepipeline" {
  name   = "${var.name_prefix}-codepipeline-policy"
  role   = aws_iam_role.codepipeline.id
  policy = data.aws_iam_policy_document.codepipeline_policy.json
}

# -----------------------------------------------------------------------------
# Pipeline: Source (push a main) -> Build (docker build+push ECR) -> Deploy (ECS)
# -----------------------------------------------------------------------------
resource "aws_codepipeline" "this" {
  name     = "${var.name_prefix}-pipeline"
  role_arn = aws_iam_role.codepipeline.arn
  tags     = var.tags

  artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.github.arn
        FullRepositoryId = var.github_repository_id
        BranchName       = var.github_branch
        DetectChanges    = "true" # dispara el pipeline automaticamente con cada push a la rama
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]

      configuration = {
        ProjectName = aws_codebuild_project.this.name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      version         = "1"
      input_artifacts = ["build_output"]

      configuration = {
        ClusterName = var.ecs_cluster_name
        ServiceName = var.ecs_service_name
        FileName    = "imagedefinitions.json"
      }
    }
  }
}

# -----------------------------------------------------------------------------
# Notificacion por email del estado del pipeline (succeeded/failed)
# -----------------------------------------------------------------------------
resource "aws_codestarnotifications_notification_rule" "pipeline" {
  count = var.enable_pipeline_notifications ? 1 : 0

  name        = "${var.name_prefix}-pipeline-status"
  resource    = aws_codepipeline.this.arn
  detail_type = "FULL"

  event_type_ids = [
    "codepipeline-pipeline-pipeline-execution-succeeded",
    "codepipeline-pipeline-pipeline-execution-failed",
  ]

  target {
    address = var.sns_topic_arn
  }

  tags = var.tags
}
