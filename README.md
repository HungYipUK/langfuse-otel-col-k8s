## Enable microk8s modules
```bash
microk8s enable cert-manager
microk8s enable hostpath-storage
microk8s enable metallb
microk8s enable ingress
```

## Install ClickHouse Operator
```bash
helm install clickhouse-operator oci://ghcr.io/clickhouse/clickhouse-operator-helm \
   --create-namespace \
   -n clickhouse-operator
```

## Install LangFuse Helm Chart
```bash
helm repo add langfuse https://langfuse.github.io/langfuse-k8s
helm repo update
kubectl create namespace langfuse
helm install langfuse langfuse/langfuse -n langfuse -f langfuse/values.yaml

# port-forward to langfuse-web
kubectl port-forward service/langfuse-web -n langfuse --address 0.0.0.0 3000:3000
```

## Clean up LangFuse Helm Chart
```bash
helm list -A
# helm uninstall <release> -n <namespace>
helm uninstall langfuse -n langfuse

kubectl get pvc -n <namespace>
# kubectl delete pvc -l app.kubernetes.io/instance=<release-name> -n <namespace>
kubectl delete pvc -l app.kubernetes.io/instance=langfuse-clickhouse -n langfuse
kubectl delete pvc -l app.kubernetes.io/instance=langfuse-keeper -n langfuse
kubectl delete pvc -l app.kubernetes.io/instance=langfuse -n langfuse

kubectl delete namespace <namespace>
```

## Install OpenTelemetry Collector k8s stack
```bash
kubectl create namespace opentelemetry-collector

# Create the DaemonSet and Service
# kubectl apply -f https://raw.githubusercontent.com/open-telemetry/opentelemetry-collector/v0.165.0/examples/k8s/otel-config.yaml
kubectl apply -f otel-collector/otel-config.yaml

# Create the ingress
kubectl apply -f otel-collector/otel-ingress.yaml

# port-forward to openTelemetry otlp receiver
kubectl port-forward service/otel-collector -n opentelemetry-collector --address 0.0.0.0 4317:4317 4318:4318 8888:8888

# test ingress setting with curl, after updated the /etc/hosts then 
curl -v -H "Host: langfuse-demo.local" http://127.0.0.1/metrics

# Copy file from pod to host, but tar must be available in the container
kubectl cp opentelemetry-collector/otel-collector-mnggw:/conf/bearer-tokens .

kubectl exec -n opentelemetry-collector otel-collector-mnggw -- cat /conf/bearer-token

# to cleanup
kubectl delete -f otel-collector/otel-ingress.yaml
kubectl delete -f otel-collector/otel-config.yaml
```

## Ingress config for OpenTelemetry grpc routing
```yaml
---
apiVersion: traefik.io/v1alpha1
kind: IngressRouteTCP
metadata:
  name: otel-collector-grpc
  namespace: opentelemetry-collector
spec:
  entryPoints:
    - web
  routes:
    - match: HostSNI(`*`)
      services:
        - name: otel-collector
          port: 4317
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: otel-collector-grpc
  namespace: opentelemetry-collector
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
    traefik.ingress.kubernetes.io/router.tls: "false"
spec:
  ingressClassName: traefik
  rules:
    - host: otel-collector-grpc.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: otel-collector
                port:
                  number: 4317
```




```bash
docker run --rm --network host \
  ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:latest traces --help

docker run --rm --network host \
  ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:latest \
  traces --otlp-endpoint otel-collector-grpc.local:80 --otlp-insecure \
  --otlp-header "authorization=\"Bearer user1-token\"" --duration inf --interval 1s


docker run --rm --network host \
  -e GRPC_GO_LOG_SEVERITY_LEVEL=info \
  -e GRPC_GO_LOG_VERBOSITY_LEVEL=99 \
  ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:latest \
  traces --otlp-endpoint otel-collector-grpc.local:80 --otlp-insecure --otlp-insecure-skip-verify \
  --otlp-header "authorization=\"Bearer user1-token\"" --traces 5
```