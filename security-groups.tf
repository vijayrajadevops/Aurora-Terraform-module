module "aurora_postgres_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"
  count   = var.enabled ? 1 : 0

  name                = local.instance_name
  description         = "Security group for ${local.instance_name} Aurora PostgreSQL RDS instance"
  vpc_id              = data.aws_vpc.this.id
  ingress_cidr_blocks = var.settings.source_cidrs
  ingress_rules       = ["postgresql-tcp"]
  ingress_with_source_security_group_id = flatten([
    for sg in data.aws_security_groups.this : [
      for id in sg.ids : {
        rule                     = "postgresql-tcp"
        source_security_group_id = id
      }
    ]
  ])
}
