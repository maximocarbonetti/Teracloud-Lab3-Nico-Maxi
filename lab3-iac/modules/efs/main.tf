# Recursos del modulo efs
#
# Un filesystem EFS con un mount target por subnet privada (una por AZ,
# para que las instancias EC2 del cluster ECS lo puedan montar sin importar
# en que AZ caiga la task de MySQL), cifrado en reposo, y un access point
# con el UID/GID de mysql para que la task no tenga problemas de permisos.

resource "aws_efs_file_system" "this" {
  creation_token   = var.name
  encrypted        = true
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  tags = merge(var.tags, { Name = var.name })
}

resource "aws_efs_mount_target" "this" {
  count = length(var.subnet_ids)

  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = var.subnet_ids[count.index]
  security_groups = var.security_group_ids
}

resource "aws_efs_access_point" "mysql" {
  file_system_id = aws_efs_file_system.this.id

  posix_user {
    uid = var.posix_uid
    gid = var.posix_gid
  }

  root_directory {
    path = var.access_point_path

    creation_info {
      owner_uid   = var.posix_uid
      owner_gid   = var.posix_gid
      permissions = "755"
    }
  }

  tags = merge(var.tags, { Name = "${var.name}-mysql-ap" })
}
