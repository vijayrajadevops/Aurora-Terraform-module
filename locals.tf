locals {
  default_tags         = data.aws_default_tags.this.tags
  instance_name        = replace("pgsql-${local.default_tags.product}-${local.default_tags.environment}-${local.default_tags.domain}-${var.name}", "_", "-")
  vpc_name             = coalesce(var.settings.vpc_name, "${local.default_tags.product}/${local.default_tags.environment}")
  subnets              = data.aws_subnets.this.ids
  admin_user_name      = "admin_user"
  rds_logs_bucket_name = coalesce(var.settings.rds_logs_to_s3.bucket_name, format("%s-%s-audit-logs", local.default_tags.product, local.default_tags.environment))

  mandatory_parameters = {
    "rds.force_ssl" = { value = "1", apply_method = "pending-reboot" }
    "pgaudit.log"   = { value = "all", apply_method = "immediate" }
  }
  default_parameters = {
    "shared_preload_libraries"        = { value = "pg_stat_statements,pgaudit", apply_method = "pending-reboot" }
    "track_activity_query_size"       = { value = "4096", apply_method = "pending-reboot" }
    "pg_stat_statements.max"          = { value = "10000", apply_method = "pending-reboot" }
    "pg_stat_statements.track"        = { value = "ALL", apply_method = "immediate" }
    "track_io_timing"                 = { value = "1", apply_method = "pending-reboot" }
    "log_autovacuum_min_duration"     = { value = "0", apply_method = "immediate" }
    "log_lock_waits"                  = { value = "1", apply_method = "immediate" }
    "log_min_duration_statement"      = { value = "1000", apply_method = "immediate" }
    "log_min_messages"                = { value = "warning", apply_method = "immediate" }
    "autovacuum_analyze_scale_factor" = { value = "0.1", apply_method = "immediate" }
    "autovacuum_analyze_threshold"    = { value = "500", apply_method = "immediate" }
    "autovacuum_vacuum_cost_delay"    = { value = "20", apply_method = "immediate" }
    "autovacuum_vacuum_scale_factor"  = { value = "0.2", apply_method = "immediate" }
    "vacuum_cost_limit"               = { value = "800", apply_method = "immediate" }
    "random_page_cost"                = { value = "1", apply_method = "immediate" }
    "maintenance_work_mem"            = { value = "1000000", apply_method = "immediate" }
    "log_statement"                   = { value = "all", apply_method = "immediate" }
    "log_connections"                 = { value = "1", apply_method = "immediate" }
    "log_disconnections"              = { value = "1", apply_method = "immediate" }
    "log_duration"                    = { value = "1", apply_method = "immediate" }
  }
  merged_parameters = [for param_name, param_value in(merge(local.default_parameters, var.settings.parameters, local.mandatory_parameters)) : {
    name         = param_name
    value        = param_value.value
    apply_method = param_value.apply_method
    }
  ]

  # Build local map for databases - create section privileges with role name same as database name
  databases = {
    for db_name, db_v in var.databases :
    db_name => try(db_v.privileges, false) == false ? {
      connection_limit = try(db_v.connection_limit, null)
      extensions       = try(db_v.extensions, null)
      # tflint-ignore: terraform_deprecated_interpolation
      privileges = { "${db_name}" = {} }
      } : {
      connection_limit = try(db_v.connection_limit, null)
      extensions       = try(db_v.extensions, null)
      privileges       = db_v.privileges
    }
  }

  # Build local map for roles
  roles = {
    for role in flatten([
      # Add all definded roles in var.role
      [
        for role_name, role_v in var.roles : [{
          role_name = role_name
          password  = role_v.password
          member_of = role_v.member_of
        }]
      ],
      # Create role if in parameters, database has no privileges section and role is not defined
      [
        for db_name, db_v in var.databases : [{
          role_name = db_name
          password  = null
          member_of = []
        }] if try(db_v.privileges, false) == false && try(var.roles[db_name], false) == false
      ]
      ]) : role.role_name => {
      password  = role.password
      member_of = role.member_of
    }
  }

  role_secrets = {
    for item in flatten([
      for db_name, db_v in local.databases : [
        for role, _ in db_v.privileges : {
          database = db_name
          role     = role
          password = local.decrypted_roles[role].password
        } if var.enabled && var.configuration_enabled
      ]
    ]) : "${item.database}/${item.role}" => item
  }

  #proxy_secrets = {
  #  for secret_name, secret_value in(length(module.role_credential_secret) > 0 ? module.role_credential_secret : var.enabled ? { "admin_user" = module.admin_credential_secret[0] } : {}) : secret_name => {
  #    description = "PostgreSQL ${secret_name} user password"
  #    arn         = secret_value.arn
  #    kms_key_id  = local.phi ? module.kms[0].key_arn : data.aws_kms_key.this[0].arn
  #  } if var.enabled
  #}

  decrypted_roles = {
    for role, role_v in local.roles : role => {
      member_of = try(role_v.member_of, [])
      password  = role_v.password != null ? data.aws_kms_secrets.role_credentials[0].plaintext["${role}_role_password"] : random_password.roles[role].result
    } if var.enabled && var.configuration_enabled
  }

  roles_with_password = {
    for _, cred in flatten([
      for _role, _role_v in local.roles : {
        role_name = _role
        password  = _role_v.password
      } if _role_v.password != null
    ]) : cred.role_name => cred.password
  }

  roles_with_nopass = {
    for _, cred in flatten([
      for _role, _role_v in local.roles : {
        role_name = _role
        password  = _role_v.password
      } if _role_v.password == null
    ]) : cred.role_name => cred.password
  }
}
