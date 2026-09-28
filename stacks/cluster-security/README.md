# cluster-security

Runs the public security visibility stack:

1. `trivy-operator`
2. `kyverno`

The stack starts with reporting and audit behavior. It is intended to surface findings without blocking existing workloads by default.

## Expected Behavior

- Trivy Operator runs in the `trivy-system` namespace and creates Kubernetes
  report resources such as `VulnerabilityReport` and `ConfigAuditReport`.
- Kyverno runs in the `kyverno` namespace and installs Productive K3S audit
  ClusterPolicies.
- Policies are installed in `Audit` mode by default. They report findings but do
  not reject workloads.
- No public HTTP endpoint or ingress is created by this stack.

## Manual Checks

```bash
kubectl get pods -n trivy-system
kubectl get pods -n kyverno
kubectl get clusterpolicy
kubectl get vulnerabilityreports -A
kubectl get configauditreports -A
kubectl get policyreports -A
```

Fresh clusters may need a few minutes before Trivy report objects appear because
scanner data must be pulled and existing workloads must be reconciled.
