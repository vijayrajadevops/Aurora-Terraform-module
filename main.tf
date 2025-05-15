
# trivy:ignore:AVD-AWS-0343
module "aurora_postgres" {
  source  = "terraform-aws-modules/rds-aurora/aws"
  version = "~> 9.0"
  count   = var.enabled ? 1 : 0

  name                         = local.instance_name
  engine                       = "aurora-postgresql"
  engine_version               = var.settings.engine_version
  storage_encrypted            = true
  kms_key_id                   = module.kms[0].key_arn
  master_username              = local.admin_user_name
  master_password              = var.settings.admin_password != null ? data.aws_kms_secrets.admin_credential[0].plaintext["password"] : random_password.admin[0].result
  manage_master_user_password  = false
  backup_retention_period      = var.settings.backup_retention_days
  preferred_backup_window      = var.settings.backup_window
  preferred_maintenance_window = var.settings.maintenance_window
  deletion_protection          = var.settings.deletion_protection
  skip_final_snapshot          = true
  copy_tags_to_snapshot        = true
  apply_immediately            = true
  autoscaling_enabled          = var.settings.autoscaling_enabled
  instance_class               = var.settings.instance_class
  instances                    = var.instances

  vpc_security_group_ids                        = [module.aurora_postgres_security_group[0].security_group_id]
  create_db_subnet_group                        = true
  create_db_cluster_parameter_group             = true
  create_security_group                         = false
  db_cluster_parameter_group_parameters         = local.merged_parameters
  db_cluster_parameter_group_family             = var.settings.db_cluster_parameter_group_family
  iam_role_name                                 = local.instance_name
  iam_role_description                          = format("Monitoring role for %s", local.instance_name)
  iam_role_use_name_prefix                      = true
  cluster_monitoring_interval                   = 30
  cluster_performance_insights_retention_period = 7
  cluster_performance_insights_kms_key_id       = module.kms[0].key_arn
  cluster_performance_insights_enabled          = true

  subnets = local.subnets
  serverlessv2_scaling_configuration = {
    min_capacity = var.settings.min_capacity
    max_capacity = var.settings.max_capacity
  }

  enabled_cloudwatch_logs_exports        = ["postgresql"]
  cloudwatch_log_group_kms_key_id        = module.kms[0].key_arn
  cloudwatch_log_group_retention_in_days = var.settings.log_retention_days
}

module "aurora_postgres_configuration" {
  source  = "./modules/postgresql-configuration"
  enabled = var.enabled && var.configuration_enabled
  settings = {
    host     = try(module.aurora_postgres[0].cluster_endpoint, null)
    username = try(module.aurora_postgres[0].cluster_master_username, null)
    password = var.settings.admin_password != null ? data.aws_kms_secrets.admin_credential[0].plaintext["password"] : random_password.admin[0].result
    port     = try(module.aurora_postgres[0].cluster_port, 0)
  }
  roles     = local.decrypted_roles
  databases = local.databases
}
