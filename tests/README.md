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
make -C tests test-clean-vms
make -C tests test-clean-artifacts
make -C tests test-clean-all
```

Use detailed targets from inside `tests/`:

```bash
make -C tests validate-layout
make -C tests test-static ADDON=nginx
make -C tests test-contract ADDON=nginx
make -C tests test-live ADDON=nginx KUBECONFIG=~/.kube/config
make -C tests test-runtime-contract
make -C tests test-live-matrix-ubuntu24 PRODUCTIVE_K3S_CORE_REPO_DIR=/path/to/productive-k3s-core
make -C tests test-live-matrix-ubuntu24 PRODUCTIVE_K3S_CORE_REPO_URL=https://github.com/productive-k3s/productive-k3s-core.git PRODUCTIVE_K3S_CORE_REPO_REF=development
```

`test-live-matrix-ubuntu24` uses the existing `productive-k3s-core` Multipass harness to bootstrap a clean Ubuntu 24.04 VM, then runs the add-on live matrix inside that VM. It requires:

- `PRODUCTIVE_K3S_CORE_REPO_DIR` or `PRODUCTIVE_K3S_CORE_REPO_URL` + `PRODUCTIVE_K3S_CORE_REPO_REF`
- `multipass`

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
