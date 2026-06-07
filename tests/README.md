# Tests

This folder contains repository-level validation entrypoints for:

- `addons/`
- `stacks/`

Current levels:

- `static`: local layout and source-tree checks
- `contract`: validation against a selected `productive-k3s-core` engine
- `live`: manual package-first install checks

Use the repository root targets:

```bash
make test-static ADDON=nginx
make test-contract ADDON=nginx
make test-live ADDON=nginx KUBECONFIG=~/.kube/config
make test-matrix
```

When validating stack content before the next Core release is published, point the runner to a newer Core revision:

```bash
make test-matrix CORE_VERSION=development
make test-contract STACK=base PRODUCTIVE_K3S_CORE_REPO_DIR=../productive-k3s-core
```
