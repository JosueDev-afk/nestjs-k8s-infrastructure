variable "name" {
  description = "Prefijo de nombre para la VPC y sus recursos (p. ej. nestjs-dev)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR de la VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Zonas de disponibilidad (mínimo 2, recomendado 3)"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDRs de subnets públicas (solo ALB/NLB y NAT gateways)"
  type        = list(string)
}

variable "private_app_subnet_cidrs" {
  description = "CIDRs de subnets privadas de aplicación (nodos EKS); egress vía NAT"
  type        = list(string)
}

variable "private_data_subnet_cidrs" {
  description = "CIDRs de subnets privadas de datos (RDS/DocumentDB/ElastiCache); sin ruta a internet"
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "true = 1 NAT compartido (dev, barato); false = 1 NAT por AZ (prod, tolerante a fallo de AZ)"
  type        = bool
  default     = true
}

variable "enable_interface_endpoints" {
  description = "Crear VPC endpoints de interfaz (ECR, Secrets Manager, CloudWatch Logs, STS) para no salir por NAT"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags comunes"
  type        = map(string)
  default     = {}
}
