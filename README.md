## Enable microk8s modules
```bash
microk8s enable cert-manager
microk8s enable hostpath-storage
microk8s enable metallb
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
# kubectl apply -f https://raw.githubusercontent.com/open-telemetry/opentelemetry-collector/v0.165.0/examples/k8s/otel-config.yaml
kubectl apply -f otel-collector/otel-config.yaml

# port-forward to openTelemetry otlp receiver
kubectl port-forward service/otel-collector -n langfuse --address 0.0.0.0 4317:4317 4318:4318 8888:8888

# Copy file from pod to host, but tar must be available in the container
kubectl cp langfuse/otel-collector-mnggw:/conf/bearer-tokens .


kubectl exec -n langfuse otel-collector-mnggw -- cat /conf/bearer-token
```