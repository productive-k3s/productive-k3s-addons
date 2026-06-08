# Make targets

Repository-level commands:

```bash
make validate-layout
make test-static ADDON=<name>
make test-contract ADDON=<name>
make test-live ADDON=<name> KUBECONFIG=~/.kube/config
make test-matrix
```

For coordinated work with an unreleased Core checkout:

```bash
make test-matrix PRODUCTIVE_K3S_CORE_REPO_DIR=/path/to/productive-k3s-core
```
