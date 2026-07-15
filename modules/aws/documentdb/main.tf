resource "random_password" "master" {
  length = 32
  # Solo caracteres seguros para incrustar en una URI de conexión
  special = false
}

resource "aws_security_group" "this" {
  name_prefix = "${var.cluster_identifier}-docdb-"
  description = "Acceso a DocumentDB solo desde los SG autorizados"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.cluster_identifier}-docdb" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "mongo" {
  for_each = toset(var.allowed_security_group_ids)

  security_group_id            = aws_security_group.this.id
  referenced_security_group_id = each.value
  from_port                    = 27017
  to_port                      = 27017
  ip_protocol                  = "tcp"
  description                  = "MongoDB API desde SG autorizado"
}

resource "aws_docdb_subnet_group" "this" {
  name       = "${var.cluster_identifier}-subnets"
  subnet_ids = var.subnet_ids
  tags       = var.tags
}

resource "aws_docdb_cluster_parameter_group" "this" {
  name        = "${var.cluster_identifier}-params"
  family      = var.parameter_group_family
  description = "TLS obligatorio para ${var.cluster_identifier}"

  parameter {
    name  = "tls"
    value = "enabled"
  }

  tags = var.tags
}

resource "aws_docdb_cluster" "this" {
  cluster_identifier = var.cluster_identifier
  engine             = "docdb"
  engine_version     = var.engine_version

  master_username = var.master_username
  master_password = random_password.master.result

  db_subnet_group_name            = aws_docdb_subnet_group.this.name
  vpc_security_group_ids          = [aws_security_group.this.id]
  db_cluster_parameter_group_name = aws_docdb_cluster_parameter_group.this.name

  storage_encrypted         = true
  backup_retention_period   = var.backup_retention_days
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.cluster_identifier}-final"

  enabled_cloudwatch_logs_exports = ["audit"]

  tags = var.tags
}

resource "aws_docdb_cluster_instance" "this" {
  count = var.instance_count

  identifier         = "${var.cluster_identifier}-${count.index}"
  cluster_identifier = aws_docdb_cluster.this.id
  instance_class     = var.instance_class

  tags = var.tags
}

# Credenciales + URI listas para consumo vía External Secrets Operator.
# retryWrites=false es requisito de DocumentDB (no soporta retryable writes).
resource "aws_secretsmanager_secret" "this" {
  name        = var.secret_name
  description = "Credenciales DocumentDB ${var.cluster_identifier}"
  tags        = var.tags
}

resource "aws_secretsmanager_secret_version" "this" {
  secret_id = aws_secretsmanager_secret.this.id
  secret_string = jsonencode({
    username = var.master_username
    password = random_password.master.result
    host     = aws_docdb_cluster.this.endpoint
    port     = aws_docdb_cluster.this.port
    uri      = "mongodb://${var.master_username}:${random_password.master.result}@${aws_docdb_cluster.this.endpoint}:${aws_docdb_cluster.this.port}/${var.database_name}?tls=true&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false"
  })
}
