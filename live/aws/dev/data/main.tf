provider "aws" {
  region = local.region

  default_tags {
    tags = local.tags
  }
}

locals {
  region = "us-east-1"
  env    = "dev"
  tags = {
    Project     = "nestjs-k8s-microservice-stack"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "CHANGEME-nestjs-k8s-tfstate"
    key    = "aws/dev/network/terraform.tfstate"
    region = local.region
  }
}

data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = "CHANGEME-nestjs-k8s-tfstate"
    key    = "aws/dev/eks/terraform.tfstate"
    region = local.region
  }
}

locals {
  vpc_id        = data.terraform_remote_state.network.outputs.vpc_id
  data_subnets  = data.terraform_remote_state.network.outputs.private_data_subnet_ids
  db_subnet_grp = data.terraform_remote_state.network.outputs.database_subnet_group_name
  eks_node_sg   = data.terraform_remote_state.eks.outputs.node_security_group_id
}

# --- user-service: RDS PostgreSQL ---
module "rds_postgres" {
  source = "../../../../modules/aws/rds-postgres"

  identifier     = "nestjs-${local.env}-userdb"
  instance_class = "db.t4g.micro"
  database_name  = "userdb"

  multi_az              = false # dev; prod = true
  backup_retention_days = 7
  deletion_protection   = false
  skip_final_snapshot   = true

  vpc_id                     = local.vpc_id
  db_subnet_group_name       = local.db_subnet_grp
  allowed_security_group_ids = [local.eks_node_sg]

  tags = local.tags
}

# --- product-service: DocumentDB (API MongoDB) ---
module "documentdb" {
  source = "../../../../modules/aws/documentdb"

  cluster_identifier = "nestjs-${local.env}-productdb"
  instance_class     = "db.t3.medium"
  instance_count     = 1
  database_name      = "productdb"

  backup_retention_days = 7
  deletion_protection   = false
  skip_final_snapshot   = true

  vpc_id                     = local.vpc_id
  subnet_ids                 = local.data_subnets
  allowed_security_group_ids = [local.eks_node_sg]
  secret_name                = "nestjs/${local.env}/data/documentdb"

  tags = local.tags
}

# --- notification-service: ElastiCache Redis ---
module "elasticache_redis" {
  source = "../../../../modules/aws/elasticache-redis"

  replication_group_id = "nestjs-${local.env}-notif"
  node_type            = "cache.t4g.micro"
  num_cache_clusters   = 1

  vpc_id                     = local.vpc_id
  subnet_ids                 = local.data_subnets
  allowed_security_group_ids = [local.eks_node_sg]
  secret_name                = "nestjs/${local.env}/data/redis"

  tags = local.tags
}

# --- Secretos de aplicación (no ligados a una DB) ---
resource "random_password" "jwt" {
  length  = 48
  special = false
}

resource "aws_secretsmanager_secret" "jwt" {
  name        = "nestjs/${local.env}/app/jwt"
  description = "JWT secret compartido por los servicios NestJS"
  tags        = local.tags
}

resource "aws_secretsmanager_secret_version" "jwt" {
  secret_id     = aws_secretsmanager_secret.jwt.id
  secret_string = jsonencode({ JWT_SECRET = random_password.jwt.result })
}

# --- DSN para postgres_exporter (observabilidad): la password del master
#     user vive en el secreto gestionado por RDS; aquí se compone la URI ---
data "aws_secretsmanager_secret_version" "rds_master" {
  secret_id  = module.rds_postgres.secret_ref
  depends_on = [module.rds_postgres]
}

locals {
  rds_creds = jsondecode(data.aws_secretsmanager_secret_version.rds_master.secret_string)
}

resource "aws_secretsmanager_secret" "postgres_exporter_dsn" {
  name        = "nestjs/${local.env}/observability/postgres-exporter"
  description = "DATA_SOURCE_NAME para prometheus-postgres-exporter"
  tags        = local.tags
}

resource "aws_secretsmanager_secret_version" "postgres_exporter_dsn" {
  secret_id = aws_secretsmanager_secret.postgres_exporter_dsn.id
  secret_string = jsonencode({
    DATA_SOURCE_NAME = "postgresql://${local.rds_creds.username}:${urlencode(local.rds_creds.password)}@${module.rds_postgres.endpoint}:${module.rds_postgres.port}/${module.rds_postgres.database_name}?sslmode=require"
  })
}

# --- Outputs consumidos por la capa platform y por values.prod.yaml del chart ---
output "postgres_endpoint" {
  value = module.rds_postgres.endpoint
}

output "postgres_secret_arn" {
  value = module.rds_postgres.secret_ref
}

output "documentdb_endpoint" {
  value = module.documentdb.endpoint
}

output "documentdb_secret_arn" {
  value = module.documentdb.secret_ref
}

output "redis_endpoint" {
  value = module.elasticache_redis.endpoint
}

output "redis_secret_arn" {
  value = module.elasticache_redis.secret_ref
}

output "jwt_secret_arn" {
  value = aws_secretsmanager_secret.jwt.arn
}

output "postgres_exporter_dsn_secret_arn" {
  value = aws_secretsmanager_secret.postgres_exporter_dsn.arn
}
