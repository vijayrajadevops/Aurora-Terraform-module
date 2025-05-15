resource "random_password" "admin" {
  count = var.settings.admin_password == null ? 1 : 0

  length           = 32
  numeric          = false
  special          = true
  override_special = "$!&*="
}

resource "random_password" "roles" {
  for_each = local.roles_with_nopass

  length           = 32
  numeric          = false
  special          = true
  override_special = "$!&*="
}

module "admin_credential_secret" {
  source = "git::ssh://git@github.com/modmed/terraform-aws-secret-manager?ref=1.2.0"
  count  = var.enabled ? 1 : 0

  name = "aurora/${module.aurora_postgres[0].cluster_id}/admin"
  settings = {
    description = "Admin credential for ${module.aurora_postgres[0].cluster_id} Aurora cluster"
    kms_key_id  = module.kms[0].key_arn
    secret_string = {
      "username"             = local.admin_user_name
      "password"             = var.settings.admin_password != null ? data.aws_kms_secrets.admin_credential[0].plaintext["password"] : random_password.admin[0].result
      "engine"               = "aurora-postgresql"
      "host"                 = module.aurora_postgres[0].cluster_endpoint
      "port"                 = module.aurora_postgres[0].cluster_port
      "dbInstanceIdentifier" = module.aurora_postgres[0].cluster_id
      "dbname"               = "postgres"
      "DATABASE_URL"         = var.settings.admin_password != null ? "postgres://${local.admin_user_name}:${data.aws_kms_secrets.admin_credential[0].plaintext["password"]}@${module.aurora_postgres[0].cluster_endpoint}/postgres" : "postgres://${local.admin_user_name}:${random_password.admin[0].result}@${module.aurora_postgres[0].cluster_endpoint}/postgres"
    }
  }
}


module "role_credential_secret" {
  source   = "git::ssh://git@github.com/modmed/terraform-aws-secret-manager?ref=1.2.0"
  for_each = var.enabled ? local.role_secrets : {}

  name = "rds/${module.aurora_postgres[0].cluster_id}/${each.key}"
  settings = {
    description = "${each.value.role} role credential to ${each.value.database} database for ${module.aurora_postgres[0].cluster_id} Aurora cluster"
    kms_key_id  = module.kms[0].key_arn
    secret_string = {
      "username"             = each.value.role
      "password"             = each.value.password
      "engine"               = "aurora-postgresql"
      "host"                 = module.aurora_postgres[0].cluster_endpoint
      "port"                 = module.aurora_postgres[0].cluster_port
      "dbInstanceIdentifier" = module.aurora_postgres[0].cluster_id
      "dbname"               = each.value.database
      "app_platform"         = "ruby"
      "DATABASE_URL"         = "postgres://${each.value.role}:${each.value.password}@${module.aurora_postgres[0].cluster_endpoint}/${each.value.database}"
      #"PROXY_URL"            = "postgres://${each.value.role}:${each.value.password}@${module.proxy[0].proxy_endpoint}/${each.value.database}"
    }
  }
}
