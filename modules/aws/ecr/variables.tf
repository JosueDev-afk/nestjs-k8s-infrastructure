variable "repository_names" {
  description = "Nombres de los repositorios ECR a crear"
  type        = list(string)
}

variable "max_images" {
  description = "Imágenes a retener por repositorio (lifecycle policy)"
  type        = number
  default     = 20
}

variable "tags" {
  type    = map(string)
  default = {}
}
