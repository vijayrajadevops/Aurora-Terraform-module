module "kms" {
  source = "git::ssh://git@github.com/modmed/terraform-aws-kms?ref=1.3.0"
  count  = var.enabled ? 1 : 0

  name     = "aurora/${local.instance_name}"
  settings = { policy = data.aws_iam_policy_document.kms.json }
}

moved {
  from = module.kms
  to   = module.kms[0]
}
