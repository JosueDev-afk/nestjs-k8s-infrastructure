resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = var.chart_version
  namespace        = "external-secrets"
  create_namespace = true

  values = [yamlencode({
    installCRDs = true
    serviceAccount = {
      annotations = var.service_account_annotations
    }
  })]
}

# Config del provider por nube. Se construye como YAML (yamldecode unifica
# los tipos; un conditional entre objetos aws/azurekv distintos no compila).
locals {
  secret_store_provider = yamldecode(var.secret_store.type == "aws" ? <<-EOT
    aws:
      service: SecretsManager
      region: ${var.secret_store.region}
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets
            namespace: external-secrets
    EOT
    : <<-EOT
    azurekv:
      authType: WorkloadIdentity
      vaultUrl: ${var.secret_store.vault_url}
      serviceAccountRef:
        name: external-secrets
        namespace: external-secrets
    EOT
  )
}

# NOTA: kubernetes_manifest requiere acceso al API server en fase de plan;
# aplicar esta capa después de que el clúster exista (orden: network -> eks
# -> data -> platform).
resource "kubernetes_manifest" "cluster_secret_store" {
  depends_on = [helm_release.external_secrets]

  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ClusterSecretStore"
    metadata = {
      name = "default"
    }
    spec = {
      provider = local.secret_store_provider
    }
  }
}

resource "kubernetes_manifest" "external_secret" {
  for_each = var.external_secrets

  depends_on = [kubernetes_manifest.cluster_secret_store]

  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = each.key
      namespace = each.value.namespace
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        kind = "ClusterSecretStore"
        name = "default"
      }
      target = {
        name           = each.key
        creationPolicy = "Owner"
      }
      data = [
        for d in each.value.data : {
          secretKey = d.secret_key
          remoteRef = merge(
            { key = d.remote_key },
            d.property != null ? { property = d.property } : {}
          )
        }
      ]
    }
  }
}
