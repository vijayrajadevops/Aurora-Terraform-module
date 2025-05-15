variable "enabled" {
  type        = bool
  description = "Bool to decide if RDS resources are created"
  default     = true
}

variable "configuration_enabled" {
  type        = bool
  description = "Bool to decide if one wants to configure Aurora PostgreSQL RDS instance with DBs,roles,permissions"
  default     = true
}

variable "name" {
  type        = string
  description = "Name of Aurora PostgreSQL instance"
}

variable "settings" {
  type = object({
    admin_password                    = optional(string)
    engine_version                    = optional(string, "15.3")
    engine_mode                       = optional(string, "provisioned")
    apply_immediately                 = optional(bool, true)
    multi_az                          = optional(bool, false)
    vpc_name                          = optional(string) # VPC Name ex klara/stg - if not provided name is generated from tags $product/$environment
    subnet_type                       = optional(string, "database")
    storage_type                      = optional(string, "gp3") # Storage type gp2,gp3,io1,io2 https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_Storage.html#gp3-storage
    iops                              = optional(number)        # Storage size lower than 400GB can't set iops; for io storage type minimum value is 1000
    throughput                        = optional(number)        # Storage size lower than 400GB can't set throughput
    allocated_storage                 = optional(number, 20)    # Minimal size for GP3 is 20G
    backup_window                     = optional(string, "04:00-05:00")
    backup_retention_days             = optional(number, 7) # Snapshot retention in days
    maintenance_window                = optional(string, "Mon:07:00-Mon:09:00")
    source_cidrs                      = list(string)               # Allowed CIDR blocks - used in security group
    source_security_group_names       = optional(list(string), []) # Allowed Source Security Group Names; Used as filter to query Security Group ID
    log_retention_days                = optional(number, 7)        # CloudWatch log retention in days
    deletion_protection               = optional(bool, true)
    min_capacity                      = optional(number, 0.5)
    max_capacity                      = optional(number, 2.0)
    autoscaling_enabled               = optional(bool, false)
    db_cluster_parameter_group_family = optional(string, "aurora-postgresql15")
    instance_class                    = optional(string, "db.serverless")
    parameters = optional(map(object({
      value        = string
      apply_method = optional(string, "immediate")
    })))
    rds_logs_to_s3 = optional(object({                     # Object that represents configuration for lambda that transfers logs to S3 bucket
      enabled     = optional(bool, false)                  # Create resources needed for transfering RDS logs to S3 bucket
      bucket_name = optional(string)                       # Optional name of the S3 Bucket
      schedule    = optional(string, "cron(30 8 * * ? *)") # EventBridge rule schedule when to trigger transfering logs to S3 in UTC
      }), {
      enabled = false # If `rds_logs_to_s3` is not defined then disable by default
    })
    tags = optional(map(string), {}) # Optional map to define additional tags added to resources
  })
  description = "Settings of Aurora PostgreSQL instance"
}

variable "roles" {
  type = map(object({
    password  = optional(string)
    member_of = optional(list(string), [])
  }))
  default     = {}
  description = "Roles created inside of Aurora PostgreSQL instance"
}

variable "databases" {
  type        = any
  description = "Database names created inside Aurora PostgreSQL instance"
}

variable "instances" {
  type = map(object({}))

  default = {
    one   = {}
    two   = {}
    three = {}
  }
}
