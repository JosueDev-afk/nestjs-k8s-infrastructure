variable "cluster_name" {
  description = "Nombre del clúster EKS"
  type        = string
}

variable "cluster_version" {
  description = "Versión de Kubernetes"
  type        = string
  default     = "1.30"
}

variable "vpc_id" {
  description = "VPC donde vive el clúster (output del módulo network)"
  type        = string
}

variable "subnet_ids" {
  description = "Subnets privadas de aplicación para los nodos"
  type        = list(string)
}

variable "endpoint_public_access" {
  description = "Exponer el API server públicamente (restringido por CIDR). false = solo acceso privado"
  type        = bool
  default     = true
}

variable "endpoint_public_access_cidrs" {
  description = "CIDRs con acceso al API server público (CI, VPN). Nunca dejar 0.0.0.0/0 en prod"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "node_instance_types" {
  description = "Tipos de instancia del node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 5
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_capacity_type" {
  description = "ON_DEMAND o SPOT"
  type        = string
  default     = "ON_DEMAND"
}

variable "tags" {
  type    = map(string)
  default = {}
}
