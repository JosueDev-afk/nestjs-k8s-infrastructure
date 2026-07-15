# Stack de observabilidad orientado a las 4 señales doradas (latencia,
# tráfico, errores, saturación). Los microservicios solo hablan OTLP con el
# Collector y exponen /metrics: cero acoplamiento a proveedor.

# --- Métricas: kube-prometheus-stack (Prometheus Operator + Grafana +
#     node-exporter + kube-state-metrics + alertas por defecto) ---
resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = var.chart_versions["kube_prometheus_stack"]
  namespace        = var.namespace
  create_namespace = true
  timeout          = 600

  values = [yamlencode({
    prometheus = {
      prometheusSpec = {
        retention = "${var.retention_days}d"
        # Descubre ServiceMonitors/PodMonitors de cualquier namespace
        serviceMonitorSelectorNilUsesHelmValues = false
        podMonitorSelectorNilUsesHelmValues     = false
        # Scrape adicional de los microservicios NestJS (prom-client /metrics)
        additionalScrapeConfigs = [{
          job_name = "microservices"
          kubernetes_sd_configs = [{
            role       = "pod"
            namespaces = { names = [var.app_namespace] }
          }]
          relabel_configs = [
            {
              source_labels = ["__meta_kubernetes_pod_label_app_kubernetes_io_component"]
              target_label  = "service"
            },
            {
              source_labels = ["__meta_kubernetes_pod_container_port_number"]
              action        = "keep"
              regex         = "300[0-9]"
            },
          ]
        }]
        resources = {
          requests = { cpu = "250m", memory = "1Gi" }
          limits   = { memory = "2Gi" }
        }
      }
    }
    grafana = {
      adminPassword = var.grafana_admin_password
      additionalDataSources = [
        {
          name   = "Loki"
          type   = "loki"
          url    = "http://loki.${var.namespace}.svc:3100"
          access = "proxy"
        },
        {
          name   = "Tempo"
          type   = "tempo"
          url    = "http://tempo.${var.namespace}.svc:3100"
          access = "proxy"
        },
      ]
    }
    alertmanager = { enabled = true }
  })]
}

# --- Logs: Loki (single binary) + Promtail ---
# Los bloques condicionales por backend se construyen como YAML (yamldecode
# unifica tipos; un conditional entre objetos de forma distinta no compila).
locals {
  loki_storage = yamldecode(var.loki_storage.type == "s3" ? <<-EOT
    type: s3
    bucketNames:
      chunks: ${coalesce(var.loki_storage.bucket, "unused")}
      ruler: ${coalesce(var.loki_storage.bucket, "unused")}
      admin: ${coalesce(var.loki_storage.bucket, "unused")}
    s3:
      region: ${coalesce(var.loki_storage.region, "unused")}
    EOT
    : "type: filesystem"
  )

  loki_service_account = yamldecode(var.loki_storage.type == "s3" ? <<-EOT
    annotations:
      eks.amazonaws.com/role-arn: ${coalesce(var.loki_storage.role_arn, "unused")}
    EOT
    : "{}"
  )
}

resource "helm_release" "loki" {
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  version    = var.chart_versions["loki"]
  namespace  = var.namespace

  depends_on = [helm_release.kube_prometheus_stack]

  values = [yamlencode({
    deploymentMode = "SingleBinary"
    loki = {
      auth_enabled = false
      commonConfig = { replication_factor = 1 }
      storage      = local.loki_storage
      schemaConfig = {
        configs = [{
          from         = "2024-01-01"
          store        = "tsdb"
          object_store = var.loki_storage.type == "s3" ? "s3" : "filesystem"
          schema       = "v13"
          index        = { prefix = "index_", period = "24h" }
        }]
      }
    }
    singleBinary   = { replicas = 1 }
    serviceAccount = local.loki_service_account
    # Desactivar componentes del modo distribuido
    backend = { replicas = 0 }
    read    = { replicas = 0 }
    write   = { replicas = 0 }
  })]
}

resource "helm_release" "promtail" {
  name       = "promtail"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "promtail"
  version    = var.chart_versions["promtail"]
  namespace  = var.namespace

  depends_on = [helm_release.loki]

  values = [yamlencode({
    config = {
      clients = [{ url = "http://loki.${var.namespace}.svc:3100/loki/api/v1/push" }]
    }
  })]
}

# --- Trazas: Tempo ---
resource "helm_release" "tempo" {
  name       = "tempo"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "tempo"
  version    = var.chart_versions["tempo"]
  namespace  = var.namespace

  depends_on = [helm_release.kube_prometheus_stack]

  values = [yamlencode({
    tempo = {
      retention = "72h"
    }
  })]
}

# --- OpenTelemetry Collector (gateway): OTLP in -> Tempo/Prometheus out.
#     Los servicios apuntan a otel-collector.<ns>.svc:4317 y nada más. ---
resource "helm_release" "otel_collector" {
  name       = "otel-collector"
  repository = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart      = "opentelemetry-collector"
  version    = var.chart_versions["otel_collector"]
  namespace  = var.namespace

  depends_on = [helm_release.tempo]

  values = [yamlencode({
    mode  = "deployment"
    image = { repository = "otel/opentelemetry-collector-contrib" }
    config = {
      receivers = {
        otlp = {
          protocols = {
            grpc = { endpoint = "0.0.0.0:4317" }
            http = { endpoint = "0.0.0.0:4318" }
          }
        }
      }
      processors = {
        batch         = {}
        k8sattributes = {}
      }
      exporters = {
        "otlp/tempo" = {
          endpoint = "tempo.${var.namespace}.svc:4317"
          tls      = { insecure = true }
        }
        prometheus = {
          endpoint = "0.0.0.0:8889"
        }
      }
      service = {
        pipelines = {
          traces = {
            receivers  = ["otlp"]
            processors = ["k8sattributes", "batch"]
            exporters  = ["otlp/tempo"]
          }
          metrics = {
            receivers  = ["otlp"]
            processors = ["k8sattributes", "batch"]
            exporters  = ["prometheus"]
          }
        }
      }
    }
  })]
}

# --- Exporters de bases de datos gestionadas: telemetría idéntica en AWS y
#     Azure. Las credenciales llegan como Secrets creados por ESO. ---
resource "helm_release" "postgres_exporter" {
  count = var.postgres_exporter.enabled ? 1 : 0

  name       = "postgres-exporter"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus-postgres-exporter"
  version    = var.chart_versions["postgres_exporter"]
  namespace  = var.namespace

  depends_on = [helm_release.kube_prometheus_stack]

  values = [yamlencode({
    config = {
      datasource = {
        # El Secret (ESO) contiene DATA_SOURCE_NAME=postgres://user:pass@host:5432/db?sslmode=require
        existingSecret = {
          enabled = true
          name    = var.postgres_exporter.datasource_secret_name
          key     = "DATA_SOURCE_NAME"
        }
      }
    }
    serviceMonitor = { enabled = true }
  })]
}

resource "helm_release" "mongodb_exporter" {
  count = var.mongodb_exporter.enabled ? 1 : 0

  name       = "mongodb-exporter"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus-mongodb-exporter"
  version    = var.chart_versions["mongodb_exporter"]
  namespace  = var.namespace

  depends_on = [helm_release.kube_prometheus_stack]

  values = [yamlencode({
    existingSecret = {
      name = var.mongodb_exporter.uri_secret_name
      key  = "MONGODB_URI"
    }
    serviceMonitor = { enabled = true }
  })]
}

resource "helm_release" "redis_exporter" {
  count = var.redis_exporter.enabled ? 1 : 0

  name       = "redis-exporter"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus-redis-exporter"
  version    = var.chart_versions["redis_exporter"]
  namespace  = var.namespace

  depends_on = [helm_release.kube_prometheus_stack]

  values = [yamlencode({
    redisAddress = "rediss://${var.redis_exporter.redis_addr}:6379"
    auth = {
      enabled = true
      secret = {
        name = var.redis_exporter.password_secret_name
        key  = "REDIS_PASSWORD"
      }
    }
    serviceMonitor = { enabled = true }
  })]
}
