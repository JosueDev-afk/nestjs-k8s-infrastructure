output "namespace" {
  value = var.namespace
}

output "otlp_endpoint" {
  description = "Endpoint OTLP gRPC que consumen los microservicios (OTEL_EXPORTER_OTLP_ENDPOINT)"
  value       = "http://otel-collector-opentelemetry-collector.${var.namespace}.svc:4317"
}

output "prometheus_url" {
  value = "http://kube-prometheus-stack-prometheus.${var.namespace}.svc:9090"
}

output "loki_url" {
  value = "http://loki.${var.namespace}.svc:3100"
}
