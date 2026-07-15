variable "chart_version" {
  type    = string
  default = "0.9.19"
}

variable "service_account_annotations" {
  description = "Anotaciones del ServiceAccount de ESO. AWS: eks.amazonaws.com/role-arn = <IRSA role>. Azure: azure.workload.identity/client-id"
  type        = map(string)
  default     = {}
}

# Backend del ClusterSecretStore — la ÚNICA parte específica de nube.
# AWS:   { type = "aws",   region = "us-east-1" }
# Azure: { type = "azure", vault_url = "https://<kv>.vault.azure.net" }
variable "secret_store" {
  type = object({
    type      = string
    region    = optional(string)
    vault_url = optional(string)
  })
}

variable "external_secrets" {
  description = "Secrets de Kubernetes a materializar desde el backend. La clave del map es el nombre del Secret resultante (debe coincidir con existingSecret en el chart de la app)"
  type = map(object({
    namespace = string
    data = list(object({
      secret_key = string           # clave dentro del Secret de K8s (p. ej. DATABASE_PASSWORD)
      remote_key = string           # nombre/ARN del secreto en el backend
      property   = optional(string) # campo dentro del JSON del secreto remoto
    }))
  }))
  default = {}
}
