# Testing and matrix

`productive-k3s-addons` validates content against a selected `productive-k3s-core` engine.

Default CI scope:

- `static`
- `contract`

Manual validation scope:

- `live`

Typical commands:

```bash
make test-static ADDON=nginx PRODUCTIVE_K3S_CORE_REPO_DIR=/path/to/productive-k3s-core
make test-contract STACK=base PRODUCTIVE_K3S_CORE_REPO_DIR=/path/to/productive-k3s-core
make test-live ADDON=nginx KUBECONFIG=~/.kube/config
make test-matrix PRODUCTIVE_K3S_CORE_REPO_DIR=/path/to/productive-k3s-core
```
