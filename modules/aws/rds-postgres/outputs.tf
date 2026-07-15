# CONTRATO DE PARIDAD: azure/postgres-flexible expone estos mismos outputs.

output "endpoint" {
  description = "Hostname de la instancia (DATABASE_HOST)"
  value       = aws_db_instance.this.address
}

output "port" {
  value = aws_db_instance.this.port
}

output "database_name" {
  value = aws_db_instance.this.db_name
}

output "secret_ref" {
  description = "ARN del secreto (Secrets Manager) con username/password del master user; consumido por External Secrets Operator"
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}

output "security_group_id" {
  value = aws_security_group.this.id
}
