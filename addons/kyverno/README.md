# kyverno

Installs Kyverno as a public Productive K3S add-on and applies a minimal policy set in Audit mode.

This add-on does not enable broad enforcement by default. The shipped ClusterPolicies are intended to produce policy reports and warnings without blocking workloads.

## Defaults

- Namespace: `kyverno`
- Helm repository: `https://kyverno.github.io/kyverno/`
- Chart: `kyverno/kyverno`
- Chart version: `3.9.0`, verified by archive SHA-256
- Controller, hook, migration, test, and optional reports-server/PostgreSQL helper images: pinned by multi-architecture digest in `values.yaml` and `materials.lock.yaml`
- Policy validation failure action: `Audit`

Override chart identity only as a pair with `PK3S_KYVERNO_CHART_VERSION` and `PK3S_KYVERNO_CHART_SHA256`; a mismatched archive fails before installation.

## Included Policies

- `pk3s-audit-require-workload-labels`: checks common Kubernetes recommended labels on Pods.
- `pk3s-audit-disallow-latest-image-tag`: reports containers using the mutable `latest` image tag.

## Operations

Status:

```bash
kubectl get pods -n kyverno
kubectl get clusterpolicy
kubectl get policyreports -A
```

Cleanup removes the Helm release, namespace, and the Productive K3S audit policies.
