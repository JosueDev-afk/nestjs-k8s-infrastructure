variable "identifier" {
  description = "Identificador de la instancia (p. ej. nestjs-dev-userdb)"
  type        = string
}

variable "engine_version" {
  description = "Versión mayor.menor de PostgreSQL"
  type        = string
  default     = "16.3"
}

variable "parameter_group_family" {
  type    = string
  default = "postgres16"
}

variable "instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "allocated_storage" {
  description = "Storage inicial (GiB), gp3"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Techo de autoscaling de storage (GiB)"
  type        = number
  default     = 100
}

variable "database_name" {
  type    = string
  default = "userdb"
}

variable "master_username" {
  type    = string
  default = "app_user"
}

variable "multi_az" {
  description = "Standby síncrono en otra AZ (failover automático ~60-120s). Obligatorio en prod"
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Retención de backups automáticos + PITR (1-35)"
  type        = number
  default     = 7
}

variable "deletion_protection" {
  type    = bool
  default = false
}

variable "skip_final_snapshot" {
  description = "false en prod: snapshot final obligatorio al destruir"
  type        = bool
  default     = true
}

variable "performance_insights_enabled" {
  type    = bool
  default = true
}

variable "vpc_id" {
  type = string
}

variable "db_subnet_group_name" {
  description = "Subnet group de datos (output del módulo network)"
  type        = string
}

variable "allowed_security_group_ids" {
  description = "SGs con acceso a 5432 (típicamente el node SG de EKS). Seguridad por referencia, no por CIDR"
  type        = list(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}
