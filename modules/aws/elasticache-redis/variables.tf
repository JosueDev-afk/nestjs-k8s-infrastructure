variable "replication_group_id" {
  description = "Identificador del replication group (p. ej. nestjs-dev-notif)"
  type        = string
}

variable "engine_version" {
  type    = string
  default = "7.1"
}

variable "parameter_group_name" {
  type    = string
  default = "default.redis7"
}

variable "node_type" {
  type    = string
  default = "cache.t4g.micro"
}

variable "num_cache_clusters" {
  description = "1 en dev; >= 2 en prod (habilita failover automático y multi-AZ)"
  type        = number
  default     = 1
}

variable "snapshot_retention_days" {
  type    = number
  default = 1
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "Subnets privadas de datos"
  type        = list(string)
}

variable "allowed_security_group_ids" {
  description = "SGs con acceso a 6379 (node SG de EKS)"
  type        = list(string)
}

variable "secret_name" {
  description = "Nombre del secreto en Secrets Manager con auth token y endpoint"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
