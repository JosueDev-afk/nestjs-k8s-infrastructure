variable "cluster_identifier" {
  description = "Identificador del clúster (p. ej. nestjs-dev-productdb)"
  type        = string
}

variable "engine_version" {
  description = "DocumentDB compatible con API MongoDB 5.0. Validar features de Mongoose antes de migrar desde Mongo 7 (ver ADR-002)"
  type        = string
  default     = "5.0.0"
}

variable "parameter_group_family" {
  type    = string
  default = "docdb5.0"
}

variable "instance_class" {
  type    = string
  default = "db.t3.medium"
}

variable "instance_count" {
  description = "1 en dev; >= 2 en prod (réplicas en AZs distintas, failover automático)"
  type        = number
  default     = 1
}

variable "database_name" {
  description = "Nombre lógico de la DB usado en la URI (DocumentDB no la pre-crea; la crea el driver al escribir)"
  type        = string
  default     = "productdb"
}

variable "master_username" {
  type    = string
  default = "app_user"
}

variable "backup_retention_days" {
  type    = number
  default = 7
}

variable "deletion_protection" {
  type    = bool
  default = false
}

variable "skip_final_snapshot" {
  type    = bool
  default = true
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "Subnets privadas de datos"
  type        = list(string)
}

variable "allowed_security_group_ids" {
  description = "SGs con acceso a 27017 (node SG de EKS)"
  type        = list(string)
}

variable "secret_name" {
  description = "Nombre del secreto en Secrets Manager con las credenciales y la URI"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
