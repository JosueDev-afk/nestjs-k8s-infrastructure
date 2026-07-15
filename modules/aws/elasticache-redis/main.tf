resource "random_password" "auth_token" {
  length  = 32
  special = false # ElastiCache restringe los caracteres del auth token
}

resource "aws_security_group" "this" {
  name_prefix = "${var.replication_group_id}-redis-"
  description = "Acceso a Redis solo desde los SG autorizados"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.replication_group_id}-redis" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "redis" {
  for_each = toset(var.allowed_security_group_ids)

  security_group_id            = aws_security_group.this.id
  referenced_security_group_id = each.value
  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"
  description                  = "Redis desde SG autorizado"
}

resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.replication_group_id}-subnets"
  subnet_ids = var.subnet_ids
  tags       = var.tags
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id = var.replication_group_id
  description          = "Redis para notification-service"

  engine         = "redis"
  engine_version = var.engine_version
  node_type      = var.node_type
  port           = 6379

  num_cache_clusters         = var.num_cache_clusters
  automatic_failover_enabled = var.num_cache_clusters > 1
  multi_az_enabled           = var.num_cache_clusters > 1

  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = [aws_security_group.this.id]

  # Cifrado en tránsito + at-rest + AUTH obligatorios
  transit_encryption_enabled = true
  at_rest_encryption_enabled = true
  auth_token                 = random_password.auth_token.result

  snapshot_retention_limit = var.snapshot_retention_days
  parameter_group_name     = var.parameter_group_name
  apply_immediately        = false

  tags = var.tags
}

resource "aws_secretsmanager_secret" "this" {
  name        = var.secret_name
  description = "Auth token y endpoint de ElastiCache ${var.replication_group_id}"
  tags        = var.tags
}

resource "aws_secretsmanager_secret_version" "this" {
  secret_id = aws_secretsmanager_secret.this.id
  secret_string = jsonencode({
    auth_token = random_password.auth_token.result
    host       = aws_elasticache_replication_group.this.primary_endpoint_address
    port       = 6379
    tls        = true
  })
}
