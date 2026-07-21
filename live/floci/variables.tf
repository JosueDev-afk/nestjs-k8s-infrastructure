variable "floci_endpoint" {
  description = "URL base del emulador floci (todos los servicios responden aquí)"
  type        = string
  default     = "http://floci-floci-bovybt-755121-76-13-24-93.sslip.io"
}

# Toggles: se empieza solo con ECR (el apply más seguro contra el emulador) y
# se van activando capas para probar más superficie de la IaC.
variable "enable_ecr" {
  type    = bool
  default = true
}

variable "enable_network" {
  description = "VPC + subnets + NAT + endpoints (ec2). Más superficie emulada = más probabilidad de tocar una operación no soportada."
  type        = bool
  default     = false
}

variable "enable_data" {
  description = "RDS + DocumentDB + ElastiCache + Secrets Manager. Requiere enable_network."
  type        = bool
  default     = false
}
