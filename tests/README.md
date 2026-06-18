# Tests

This folder contains repository-level validation entrypoints for:

- `addons/`
- `stacks/`

Current levels:

- `static`: local layout and source-tree checks
- `contract`: validation against a selected `productive-k3s-core` engine
- `live`: manual package-first install checks

Use the root entrypoints for the main flows:

```bash
make test-all
make test-matrix
make test-live-matrix
```

Artifacts and status helpers:

```bash
make -C tests test-checkstatus-local
make -C tests test-checkstatus-matrix
make -C tests test-checkstatus-live
make -C tests test-clean-artifacts
```

Use detailed targets from inside `tests/`:

```bash
make -C tests validate-layout
make -C tests test-static ADDON=nginx
make -C tests test-contract ADDON=nginx
make -C tests test-live ADDON=nginx KUBECONFIG=~/.kube/config
make -C tests test-runtime-contract
```

`make test-all` is the local safe entrypoint:

- `validate-layout`
- `test-static`
- `test-contract`

It does not run live install checks against a real cluster.

When validating stack content before the next Core release is published, point the runner to a newer Core revision:

```bash
make test-matrix CORE_VERSION=development
make -C tests test-contract STACK=base PRODUCTIVE_K3S_CORE_REPO_DIR=../productive-k3s-core
```
