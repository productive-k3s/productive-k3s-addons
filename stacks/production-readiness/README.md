# production-readiness

Combines public operational and security readiness checks:

1. `popeye`
2. `kubent`
3. `trivy-operator`
4. `kyverno`

The stack declares all add-ons explicitly and does not depend on stack-to-stack composition.

## Expected Behavior

- Popeye runs a one-shot diagnostic Job in `pk3s-popeye` and writes a cluster
  hygiene report to the Job logs.
- Kubent runs a one-shot deprecated API scan in `pk3s-kubent` and writes the
  report to the Job logs.
- Trivy Operator runs in `trivy-system` and creates vulnerability/configuration
  report resources.
- Kyverno runs in `kyverno` and installs Productive K3S audit ClusterPolicies.
- Kyverno policies are installed in `Audit` mode by default. They report
  findings but do not reject workloads.
- No public HTTP endpoint or ingress is created by this stack.

Popeye findings are diagnostic output. By default the Productive K3S Popeye
add-on lets the Job complete and records the original scanner result as
`popeye_exit_code=<code>` in the logs.

## Manual Checks

```bash
kubectl get jobs -n pk3s-popeye
kubectl logs -n pk3s-popeye job/pk3s-popeye-scan
kubectl get jobs -n pk3s-kubent
kubectl logs -n pk3s-kubent job/pk3s-kubent-scan
kubectl get pods -n trivy-system
kubectl get pods -n kyverno
kubectl get vulnerabilityreports -A
kubectl get configauditreports -A
kubectl get policyreports -A
```

On a newly created single-node cluster, initial Popeye and Trivy findings can be
transient while pods, metrics, endpoints, and scanner databases converge.
