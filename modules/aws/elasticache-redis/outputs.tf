# CONTRATO DE PARIDAD: azure/redis-cache expone estos mismos outputs.

output "endpoint" {
  description = "Primary endpoint (REDIS_HOST)"
  value       = aws_elasticache_replication_group.this.primary_endpoint_address
}

output "port" {
  value = 6379
}

output "secret_ref" {
  description = "ARN del secreto con auth_token/host (clave 'auth_token' = REDIS_PASSWORD)"
  value       = aws_secretsmanager_secret.this.arn
}

output "security_group_id" {
  value = aws_security_group.this.id
}
