variable "namespace" {
  type    = string
  default = "observability"
}

variable "grafana_admin_password" {
  description = "Password admin de Grafana. En prod: leerla de Secrets Manager/Key Vault en la capa live, no de un tfvars"
  type        = string
  sensitive   = true
}

variable "app_namespace" {
  description = "Namespace donde corren los microservicios (para scrape y logs)"
  type        = string
  default     = "microservices"
}

variable "retention_days" {
  description = "Retención de métricas en Prometheus"
  type        = number
  default     = 15
}

variable "loki_storage" {
  description = "Backend de Loki: filesystem (dev) o s3 (prod). Para s3, bucket + region + IRSA role"
  type = object({
    type     = string
    bucket   = optional(string)
    region   = optional(string)
    role_arn = optional(string)
  })
  default = { type = "filesystem" }
}

# Exporters hacia las bases de datos gestionadas: misma telemetría en AWS y
# Azure (en lugar de acoplarse a CloudWatch/Azure Monitor).
variable "postgres_exporter" {
  type = object({
    enabled                = bool
    datasource_secret_name = optional(string) # Secret con clave DATA_SOURCE_NAME (URI postgres://)
  })
  default = { enabled = false }
}

variable "mongodb_exporter" {
  type = object({
    enabled         = bool
    uri_secret_name = optional(string) # Secret con clave MONGODB_URI
  })
  default = { enabled = false }
}

variable "redis_exporter" {
  type = object({
    enabled              = bool
    redis_addr           = optional(string)
    password_secret_name = optional(string) # Secret con clave REDIS_PASSWORD
  })
  default = { enabled = false }
}

variable "chart_versions" {
  description = "Versiones pinneadas de los charts"
  type        = map(string)
  default = {
    kube_prometheus_stack = "58.7.2"
    loki                  = "6.6.2"
    promtail              = "6.16.6"
    tempo                 = "1.9.0"
    otel_collector        = "0.97.1"
    postgres_exporter     = "6.0.0"
    mongodb_exporter      = "3.5.0"
    redis_exporter        = "6.0.2"
  }
}
