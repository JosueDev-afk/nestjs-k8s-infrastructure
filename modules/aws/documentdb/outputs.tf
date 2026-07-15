# CONTRATO DE PARIDAD: azure/cosmosdb-mongo expone estos mismos outputs.

output "endpoint" {
  value = aws_docdb_cluster.this.endpoint
}

output "port" {
  value = aws_docdb_cluster.this.port
}

output "database_name" {
  value = var.database_name
}

output "secret_ref" {
  description = "ARN del secreto con username/password/host/uri (clave 'uri' = MONGODB_URI)"
  value       = aws_secretsmanager_secret.this.arn
}

output "security_group_id" {
  value = aws_security_group.this.id
}
