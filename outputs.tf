output "endpoint" {
  value       = try(module.aurora_postgres[0].cluster_endpoint, "")
  description = "Aurora RDS PostreSQL instance ID"
}
