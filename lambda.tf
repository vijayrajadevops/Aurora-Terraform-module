module "transfer_rds_logs_to_s3" {
  source   = "terraform-aws-modules/lambda/aws"
  version  = "~> 7.2"
  for_each = var.enabled && var.settings.rds_logs_to_s3.enabled ? toset([local.instance_name]) : toset([])

  function_name                     = "${each.key}-logs_to_s3"
  description                       = "Transfer Aurora Serverless logs to S3 lambda for ${each.key}"
  handler                           = "main.lambda_handler"
  runtime                           = "python3.9"
  publish                           = true
  create_package                    = false
  local_existing_package            = "${path.module}/lambdas/transfer_rds_logs_to_s3_lambda.zip"
  timeout                           = 900
  tracing_mode                      = "Active"
  kms_key_arn                       = module.kms[0].key_arn
  cloudwatch_logs_kms_key_id        = module.kms[0].key_arn
  cloudwatch_logs_retention_in_days = 7
  allowed_triggers = {
    transfer_rds_logs_to_s3_rule = {
      principal  = "events.amazonaws.com"
      source_arn = aws_cloudwatch_event_rule.transfer_rds_logs_to_s3[each.key].arn
    }
  }
  attach_policy_statements = true
  policy_statements = {
    AllowListAuditLogsBucket = {
      effect    = "Allow"
      actions   = ["s3:ListBucket"]
      resources = [format("arn:aws:s3:::%s", local.rds_logs_bucket_name)]
    }
    AllowPutGetObjectsToAuditLogsBucket = {
      effect = "Allow"
      actions = [
        "s3:PutObject",
        "s3:GetObject"
      ]
      resources = [format("arn:aws:s3:::%s/%s/*", local.rds_logs_bucket_name, each.key)]
    }
    AllowEncryptDecryptToKMSviaS3 = {
      effect = "Allow"
      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:GenerateDataKey"
      ]
      resources = ["*"]
      condition = {
        "string_equals_via_service" = {
          test     = "StringEquals"
          variable = "kms:ViaService"
          values   = ["s3.${data.aws_region.this.name}.amazonaws.com"]
        }
      }
    }
    AllowCloudWatchLogAccessForAurora = {
      effect = "Allow"
      actions = [
        "logs:GetLogEvents",
        "logs:DescribeLogStreams",
        "logs:DescribeLogGroups",
        "logs:FilterLogEvents"

      ]
      resources = [
        format("arn:aws:logs:%s:%s:log-group:/aws/rds/cluster/%s/postgresql:*", data.aws_region.this.name, data.aws_caller_identity.this.account_id, each.key)
      ]
    }
  }

  tags = var.settings.tags
}

resource "aws_cloudwatch_event_rule" "transfer_rds_logs_to_s3" {
  for_each = var.enabled && var.settings.rds_logs_to_s3.enabled ? toset([local.instance_name]) : toset([])

  name                = "${each.key}-logs_to_s3"
  description         = "Trigger to transfer logs from Aurora Serverless ${each.key} to ${local.rds_logs_bucket_name} S3 bucket"
  schedule_expression = var.settings.rds_logs_to_s3.schedule

  tags = var.settings.tags
}

resource "aws_cloudwatch_event_target" "transfer_rds_logs_to_s3_lambda" {
  for_each = var.enabled && var.settings.rds_logs_to_s3.enabled ? toset([local.instance_name]) : toset([])

  rule      = aws_cloudwatch_event_rule.transfer_rds_logs_to_s3[each.key].name
  target_id = aws_cloudwatch_event_rule.transfer_rds_logs_to_s3[each.key].name
  arn       = module.transfer_rds_logs_to_s3[each.key].lambda_function_arn
  input     = <<INPUT
{
  "s3_bucket_name": "${local.rds_logs_bucket_name}",
  "log_group_name": "/aws/rds/cluster/${each.key}",
  "aws_region": "${data.aws_region.this.name}",
  "log_prefix": "${each.key}",
  "min_size": 0
}
INPUT
}
