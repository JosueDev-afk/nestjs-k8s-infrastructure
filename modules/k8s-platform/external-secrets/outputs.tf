output "cluster_secret_store_name" {
  value = "default"
}

output "managed_secret_names" {
  description = "Secrets de K8s materializados (valores para existingSecret en el chart de la app)"
  value       = keys(var.external_secrets)
}
