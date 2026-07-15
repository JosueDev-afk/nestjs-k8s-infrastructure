data "aws_region" "current" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.8"

  name = var.name
  cidr = var.vpc_cidr
  azs  = var.azs

  public_subnets   = var.public_subnet_cidrs
  private_subnets  = var.private_app_subnet_cidrs
  database_subnets = var.private_data_subnet_cidrs

  # Subnets de datos aisladas: subnet group propio y sin ruta 0.0.0.0/0
  create_database_subnet_group           = true
  create_database_subnet_route_table     = true
  create_database_internet_gateway_route = false
  create_database_nat_gateway_route      = false

  enable_nat_gateway     = true
  single_nat_gateway     = var.single_nat_gateway
  one_nat_gateway_per_az = !var.single_nat_gateway

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Tags de discovery para los load balancers gestionados por Kubernetes
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = var.tags
}

# --- VPC Endpoints: el tráfico de plataforma no sale por NAT (costo + superficie) ---

# S3 Gateway endpoint (gratuito): capas de imágenes ECR, backups, Loki/Tempo
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = concat(
    module.vpc.private_route_table_ids,
    module.vpc.database_route_table_ids,
  )
  tags = merge(var.tags, { Name = "${var.name}-s3" })
}

resource "aws_security_group" "vpc_endpoints" {
  count = var.enable_interface_endpoints ? 1 : 0

  name_prefix = "${var.name}-vpce-"
  description = "Permite HTTPS desde la VPC hacia los interface endpoints"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTPS desde la VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = merge(var.tags, { Name = "${var.name}-vpce" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_endpoint" "interface" {
  for_each = var.enable_interface_endpoints ? toset([
    "ecr.api",
    "ecr.dkr",
    "secretsmanager",
    "logs",
    "sts",
  ]) : toset([])

  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(var.tags, { Name = "${var.name}-${each.value}" })
}
