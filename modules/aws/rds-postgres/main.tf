resource "aws_security_group" "this" {
  name_prefix = "${var.identifier}-rds-"
  description = "Acceso a PostgreSQL solo desde los SG autorizados"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.identifier}-rds" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "postgres" {
  for_each = toset(var.allowed_security_group_ids)

  security_group_id            = aws_security_group.this.id
  referenced_security_group_id = each.value
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = "PostgreSQL desde SG autorizado"
}

resource "aws_db_parameter_group" "this" {
  name_prefix = "${var.identifier}-"
  family      = var.parameter_group_family
  description = "TLS obligatorio para ${var.identifier}"

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}

resource "aws_db_instance" "this" {
  identifier = var.identifier

  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  # IOPS/throughput independientes del tamaño (baseline 3000 IOPS)
  storage_type          = "gp3"
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_encrypted     = true

  db_name  = var.database_name
  username = var.master_username
  # La password la genera y rota AWS en Secrets Manager: nunca pasa por el estado en claro
  manage_master_user_password = true

  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = [aws_security_group.this.id]
  publicly_accessible    = false
  parameter_group_name   = aws_db_parameter_group.this.name

  multi_az                     = var.multi_az
  backup_retention_period      = var.backup_retention_days
  deletion_protection          = var.deletion_protection
  skip_final_snapshot          = var.skip_final_snapshot
  final_snapshot_identifier    = var.skip_final_snapshot ? null : "${var.identifier}-final"
  auto_minor_version_upgrade   = true
  performance_insights_enabled = var.performance_insights_enabled

  tags = var.tags
}
