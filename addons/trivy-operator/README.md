# trivy-operator

Installs Aqua Security Trivy Operator as a public Productive K3S add-on.

The default mode is reporting only. The operator creates Kubernetes report resources for workloads and does not block admissions.

## Defaults

- Namespace: `trivy-system`
- Helm repository: `https://aquasecurity.github.io/helm-charts`
- Chart: `trivy-operator/trivy-operator`
- Chart version: `0.35.0`
- Operator app version: `0.33.0`
- Default scanner report TTL: chart default

Override the chart version with `PK3S_TRIVY_OPERATOR_CHART_VERSION`.

## Small Cluster Notes

Trivy scans can be CPU, memory, and network intensive while image databases are pulled and workloads are assessed. For small single-node K3S clusters, keep this add-on in reporting mode and avoid adding aggressive CronJob-style external scans in the same cluster until baseline resource usage is understood.

## Operations

Status:

```bash
kubectl get pods -n trivy-system
kubectl get vulnerabilityreports -A
kubectl get configauditreports -A
```

Cleanup removes the Helm release and namespace.
