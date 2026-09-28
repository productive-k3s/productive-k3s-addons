# cluster-health Stack

Declarative source for the public cluster health and upgrade-readiness stack.

Current referenced add-ons, in installation order:

- `popeye`
- `kubent`

This stack is intentionally composed from independent add-ons. Popeye reports cluster health and configuration findings; kubent reports Kubernetes API deprecations that matter before an upgrade.

The stack does not enforce policy and does not mutate existing workloads. It creates scanner namespaces, read-only RBAC, and one-shot Jobs whose status and logs are the supported inspection surface.

## Result Interpretation

`cluster-health` is a diagnostic stack. A scanner finding does not mean the
stack installation failed.

Popeye may return a non-zero scanner exit code when it finds warnings or errors.
The Productive K3S Popeye add-on defaults to allowing findings, so the Job can
finish successfully while preserving the original scanner result in the logs as:

```text
popeye_exit_code=<code>
```

On a freshly bootstrapped cluster, some Popeye errors can be startup transients:
pods still in `ContainerCreating`, deployments with no available replicas yet,
or services whose endpoints have not been populated. Re-check current cluster
state before treating those findings as active issues:

```bash
kubectl get pods -A -o wide
kubectl get jobs -A
kubectl get endpoints -A
kubectl top nodes
```

Expected health-stack evidence is that Popeye and Kubent Jobs reach a terminal
state and produce logs. Follow-up remediation should be based on current
cluster state plus scanner logs, not on the stack install exit alone.

Current contract notes:

- source delivery stays declarative and source-oriented with `spec.resolution.mode: catalog`
- published artifacts are expected to be promoted to bundled delivery by `productive-k3s-ops`
- runtime compatibility is declared for both `k3s` and `rke2`
