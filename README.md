# Productive K3S Addons

`productive-k3s-addons` is the public Kubernetes content repository for the Productive K3S ecosystem.

It is intentionally separate from `productive-k3s-core`:

- `productive-k3s-core` is the package execution engine.
- `productive-k3s-addons` contains source content.
- `productive-k3s-addons-pro` mirrors the same structure for private or commercial content.

This repository now carries two different kinds of content:

- `addons/`: individually deployable capabilities
- `stacks/`: opinionated collections of add-ons

Core must remain valid without any predefined stack. This repository is where stack intent and add-on source packages live.

## Public exposure boundary

`productive-k3s-core` now supports one narrow, generic public exposure contract for add-ons:

- one explicit host
- one Traefik ingress
- one target service and port declared by the add-on metadata

That basic contract exists so `pk3s` and Core can expose simple add-ons with a stable UX such as:

```bash
pk3s addon install nginx --profile multipass-1-server-2-agents --public-host nginx-01.k3s.lab.internal
```

Everything beyond that remains an add-on responsibility. If an add-on needs custom paths, custom TLS resources, multiple hosts, auth middlewares, or arbitrary ingress annotations, the add-on should implement that logic itself instead of expanding Core's generic surface.

## Repository structure

```text
productive-k3s-addons/
├── addons/
├── stacks/
├── scripts/
├── docs/
└── tests/
```

## Folders

### `addons/`

Contains individual add-on source packages such as `nginx`.

Each add-on is versioned, source-oriented, and intended to be packaged into `addon.tgz` by `productive-k3s-ops`. `productive-k3s-core` validates and installs the packaged artifact.

The normalized source contract is:

```text
addon.yaml
scripts/configure.sh
scripts/install.sh
scripts/validate.sh
scripts/clean.sh
scripts/backup.sh
```

Each add-on now also declares impact metadata so Core can warn in advance whether it will:

- touch cluster state
- touch host-local state
- use specific host-local capabilities such as `/etc/hosts`, Docker trust, package installation, or service enablement

### `stacks/`

Contains opinionated collections of add-ons.

A stack is not the same thing as an add-on. A stack references multiple add-ons and exists to express a higher-level operational platform shape.

The current source contract is minimal:

```text
stack.yaml
```

The first stack exported from this repository is `stacks/base`, which declaratively captures the current Productive K3S base stack intent:

- `cert-manager`
- `longhorn`
- `rancher`
- `registry`

### `scripts/`

Contains helper scripts used by addons, examples, or development workflows.

Scripts in this folder should not be required by `productive-k3s-core`.

They are specific to this repository and to the addon ecosystem.

---

### `docs/`

Contains additional documentation for the addon ecosystem.

This can include:

- addon authoring guidelines
- maturity levels
- contribution rules
- installation patterns
- compatibility notes

---

### `tests/`

Contains repository-level validation and cross-testing entrypoints.

Current workflow:

- `make test-all`: local non-live checks (`validate-layout + test-static + test-contract`)
- `make test-matrix`: run `static + contract` across all discovered add-ons and stacks
- `make test-live-matrix`: run live install validation across all discovered add-ons and stacks
- `make -C tests test-checkstatus-local|matrix|live`: summarize the latest recorded suite results

Detailed targets live under `tests/`:

- `make -C tests validate-layout`
- `make -C tests test-static`
- `make -C tests test-contract`
- `make -C tests test-live`
- `make -C tests test-live-matrix-ubuntu24`
- `make -C tests test-clean-vms`
- `make -C tests test-clean-artifacts`

Cross-testing follows the same pattern used by `productive-k3s-profiles`:

- if `PRODUCTIVE_K3S_CORE_REPO_DIR` is set, the runner uses that local checkout
- otherwise it clones `productive-k3s-core`
- if `CORE_VERSION` is omitted, the latest published `productive-k3s-core` release is used

During coordinated development of new stack contracts, prefer `CORE_VERSION=development` or `PRODUCTIVE_K3S_CORE_REPO_DIR=/path/to/productive-k3s-core` until the required Core support is released.

## Relationship with other repositories

### `productive-k3s-core`

Provides the package runtime, installation logic, validation, and cluster lifecycle.

This repository should not depend on `productive-k3s-addons` as source content.

### `productive-k3s-infra`

Provides infrastructure automation, profiles, use cases, OpenTofu, Ansible, and environment-specific orchestration.

It may consume addons from this repository when useful.

### `productive-k3s-cli`

Provides the user-facing command line interface for installing and operating Productive K3S.

In the future, it may expose commands to discover or install addons.

## Status

This repository is now the source of truth for public add-ons and stacks, including the `base` stack and the add-on-level host impact metadata consumed by Core.

## License

This project uses the same license as `productive-k3s-core`.

See [LICENSE](./LICENSE).
