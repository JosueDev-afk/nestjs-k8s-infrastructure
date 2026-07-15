# CONTRATO DE PARIDAD (modules/README.md): el módulo azure/network debe
# exponer estos mismos outputs (vpc_id -> vnet id, subnet group -> subnet
# delegada de datos, etc.).

output "vpc_id" {
  description = "ID de la VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR de la VPC"
  value       = var.vpc_cidr
}

output "public_subnet_ids" {
  description = "Subnets públicas (ALB/NLB)"
  value       = module.vpc.public_subnets
}

output "private_app_subnet_ids" {
  description = "Subnets privadas de aplicación (nodos EKS)"
  value       = module.vpc.private_subnets
}

output "private_data_subnet_ids" {
  description = "Subnets privadas de datos (sin ruta a internet)"
  value       = module.vpc.database_subnets
}

output "database_subnet_group_name" {
  description = "DB subnet group para RDS/DocumentDB/ElastiCache"
  value       = module.vpc.database_subnet_group_name
}
