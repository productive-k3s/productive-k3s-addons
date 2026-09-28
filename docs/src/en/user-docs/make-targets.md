# Make targets

These commands are mostly for repository validation and maintenance, not for the first product-level understanding of the addon catalog.

Repository-level commands:

```bash
make test-all
make test-matrix
make test-live-matrix
```

Detailed test targets live under `tests/`:

```bash
make -C tests validate-layout
make -C tests test-static ADDON=<name>
make -C tests test-contract ADDON=<name>
make -C tests test-live ADDON=<name> KUBECONFIG=~/.kube/config
```

Here, `ADDON=<name>` is a repository-side selector for catalog validation. It does not mean `productive-k3s-core` installs public add-ons by source name. The public `core` install path remains package-first with `addon install --tgz <artifact>`.

`make test-all` is the local non-live entrypoint and runs:

- `validate-layout`
- `test-static`
- `test-contract`

For coordinated work with an unreleased Core checkout:

```bash
make test-all PRODUCTIVE_K3S_CORE_REPO_DIR=/path/to/productive-k3s-core
```
