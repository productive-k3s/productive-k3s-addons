# Testing and matrix

`productive-k3s-addons` validates content against a selected `productive-k3s-core` engine.

Default CI scope:

- `static`
- `contract`

Manual validation scope:

- `live`

Typical commands:

```bash
make test-all PRODUCTIVE_K3S_CORE_REPO_DIR=/path/to/productive-k3s-core
make test-matrix PRODUCTIVE_K3S_CORE_REPO_DIR=/path/to/productive-k3s-core
make test-live-matrix PRODUCTIVE_K3S_CORE_REPO_DIR=/path/to/productive-k3s-core
make -C tests test-static ADDON=nginx PRODUCTIVE_K3S_CORE_REPO_DIR=/path/to/productive-k3s-core
make -C tests test-contract STACK=base PRODUCTIVE_K3S_CORE_REPO_DIR=/path/to/productive-k3s-core
make -C tests test-live ADDON=nginx KUBECONFIG=~/.kube/config
```

Meaning:

- `test-all`: local non-live checks only (`validate-layout + test-static + test-contract`)
- `test-live`: live validation for one selected add-on or stack
- `test-live-matrix`: live validation across every discovered add-on and stack
