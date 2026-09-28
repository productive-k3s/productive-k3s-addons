# popeye Addon

Productive K3S source package for running Popeye cluster health checks.

Popeye scans the live Kubernetes API and reports potential configuration and operational issues. This package installs a read-only ServiceAccount, ClusterRole, and one-shot Job in the `pk3s-popeye` namespace.

The default image is pinned through:

```bash
PK3S_POPEYE_IMAGE=quay.io/derailed/popeye:v0.22.1
```

The command can be tuned without editing the package:

```bash
PK3S_POPEYE_ARGS="-A -o jurassic --logs none"
```

By default, scanner findings do not make the Kubernetes Job fail:

```bash
PK3S_POPEYE_ALLOW_FINDINGS=true
```

With that default, the Job exits successfully after Popeye runs and records the
original Popeye exit code in the logs as `popeye_exit_code=<code>`. Set
`PK3S_POPEYE_ALLOW_FINDINGS=false` if you want Rancher/Kubernetes to show the
Job as failed when Popeye reports findings.

## Reading The Report

Popeye findings are diagnostic output, not an install failure by themselves.
On newly created clusters, Popeye can report temporary errors while core pods
and endpoints are still converging, for example `ContainerCreating`,
temporarily unavailable deployments, or services with no endpoint subsets yet.

For the Productive K3S health stack, the supported success signal is:

- the `pk3s-popeye-scan` Job completes
- logs are present
- the logs include `popeye_exit_code=<code>`

Use the current Kubernetes state to decide whether a finding is still active:

```bash
kubectl get pods -A -o wide
kubectl get endpoints -A
kubectl top nodes
```

The normal status path is the Job state and logs:

```bash
kubectl get job -n pk3s-popeye pk3s-popeye-scan
kubectl logs -n pk3s-popeye job/pk3s-popeye-scan
```

This add-on does not modify workload resources. It only creates the scanner namespace/RBAC/Job and uses read-only Kubernetes API permissions for analysis.
