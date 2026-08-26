# Recursos del modulo ssm-parameters
#
# Guarda la config de conexion a MySQL en Parameter Store para que el
# frontend la lea de ahi (requerimiento 8), en vez de hardcodearla en la
# task definition. La password va como SecureString.

resource "aws_ssm_parameter" "db_host" {
  name  = "${var.path_prefix}/db/host"
  type  = "String"
  value = var.db_host
  tags  = var.tags
}

resource "aws_ssm_parameter" "db_port" {
  name  = "${var.path_prefix}/db/port"
  type  = "String"
  value = tostring(var.db_port)
  tags  = var.tags
}

resource "aws_ssm_parameter" "db_name" {
  name  = "${var.path_prefix}/db/name"
  type  = "String"
  value = var.db_name
  tags  = var.tags
}

resource "aws_ssm_parameter" "db_user" {
  name  = "${var.path_prefix}/db/user"
  type  = "String"
  value = var.db_user
  tags  = var.tags
}

resource "aws_ssm_parameter" "db_password" {
  name  = "${var.path_prefix}/db/password"
  type  = "SecureString"
  value = var.db_password
  tags  = var.tags
}
