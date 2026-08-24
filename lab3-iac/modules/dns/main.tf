# Recursos del modulo dns
#
# Si ya existe la hosted zone (dominio comprado/delegado previamente), se
# usa con create_zone = false (default) y se busca via data source. Si hay
# que crearla de cero, create_zone = true.
#
# El zone_id se expone como output para que lo use el modulo acm (validacion
# DNS del certificado) y este mismo modulo (record final apuntando al ALB).

resource "aws_route53_zone" "created" {
  count = var.create_zone ? 1 : 0
  name  = var.zone_name
  tags  = var.tags
}

data "aws_route53_zone" "existing" {
  count        = var.create_zone ? 0 : 1
  name         = var.zone_name
  private_zone = false
}

locals {
  zone_id = var.create_zone ? aws_route53_zone.created[0].zone_id : data.aws_route53_zone.existing[0].zone_id
}

resource "aws_route53_record" "app" {
  zone_id = local.zone_id
  name    = var.record_name
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}
