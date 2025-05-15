
data "aws_region" "this" {}

data "aws_caller_identity" "this" {}

data "aws_default_tags" "this" {}

data "aws_vpc" "this" {
  tags = {
    Name = local.vpc_name
  }
}

data "aws_subnets" "this" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.this.id]
  }

  filter {
    name   = "tag:Name"
    values = ["${local.vpc_name}/${local.default_tags.domain}/${var.settings.subnet_type}/*"]
  }
}

data "aws_iam_policy_document" "kms" {
  statement {
    sid    = "Allow AWS logs service access KMS key"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.this.name}.amazonaws.com"]
    }
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:DescribeKey",
      "kms:GenerateDataKey*"
    ]
    resources = ["*"]
    condition {
      test     = "ArnEquals"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values = concat([
        format("arn:aws:logs:%s:%s:log-group:/aws/rds/%s/%s/upgrade", data.aws_region.this.name, data.aws_caller_identity.this.account_id, "instance", local.instance_name),
        ], var.settings.rds_logs_to_s3.enabled ? [
        format("arn:aws:logs:%s:%s:log-group:/aws/lambda/%s*-logs_to_s3", data.aws_region.this.name, data.aws_caller_identity.this.account_id, local.instance_name)
        ] : []
      )
    }
  }
}


data "aws_kms_secrets" "admin_credential" {
  count = var.enabled && var.settings.admin_password != null ? 1 : 0

  secret {
    name    = "password"
    payload = var.settings.admin_password
  }
}

data "aws_kms_secrets" "role_credentials" {
  count = var.enabled && var.configuration_enabled && length(local.roles_with_password) > 0 ? 1 : 0

  dynamic "secret" {
    for_each = local.roles_with_password
    content {
      name    = "${secret.key}_role_password"
      payload = secret.value
    }
  }
}

data "aws_security_groups" "this" {
  for_each = toset(var.settings.source_security_group_names)
  filter {
    name   = "tag:Name"
    values = [each.key]
  }
}
