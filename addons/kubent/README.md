# kubent Addon

Productive K3S source package for running Kube No Trouble deprecated API checks.

`kubent` reads live cluster resources and reports workloads that use Kubernetes APIs removed or deprecated for the selected target version. This package installs a read-only ServiceAccount, ClusterRole, and one-shot Job in the `pk3s-kubent` namespace.

The default image is pinned through:

```bash
PK3S_KUBENT_IMAGE=ghcr.io/doitintl/kube-no-trouble:0.7.3
```

The default command keeps finding deprecated resources as a reportable status rather than an installation failure:

```bash
PK3S_KUBENT_ARGS="--output text"
```

Set a target Kubernetes version when preparing an upgrade:

```bash
PK3S_KUBENT_ARGS="--target-version 1.32 --output text"
```

The normal status path is the Job state and logs:

```bash
kubectl get job -n pk3s-kubent pk3s-kubent-scan
kubectl logs -n pk3s-kubent job/pk3s-kubent-scan
```

This add-on does not mutate workload resources. It creates scanner RBAC and a Job that reads cluster and Helm release metadata.
