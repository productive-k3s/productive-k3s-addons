# Productive K3S Addons

> Work in progress.

`productive-k3s-addons` is part of the Productive K3S ecosystem.

This repository provides a space for optional, experimental, community-oriented, or non-core addons that can be used on top of a Productive K3S installation.

The goal is to keep `productive-k3s-core` focused and stable, while allowing the ecosystem to grow with additional integrations, examples, charts, and reusable components.

## Repository structure

```text
productive-k3s-addons/
├── addons/
├── examples/
├── charts/
├── scripts/
├── docs/
└── tests/
```

## Folders

### `addons/`

Contains individual addon definitions.

An addon is an optional component that can be installed on top of a Productive K3S cluster, but is not considered part of the core runtime.

Addons may include:

- Helm values
- Kubernetes manifests
- install scripts
- configuration examples
- documentation
- references to external charts or tools

Addons in this repository should be considered optional and may have different levels of maturity.

---

### `examples/`

Contains example stacks or reference compositions.

Examples are not necessarily reusable addons by themselves. They are intended to show how multiple addons, configurations, or tools can be combined for a specific scenario.

This folder can include demos, prototypes, or reference architectures.

---

### `charts/`

Contains custom Helm charts or wrapper charts maintained by this repository.

This folder should be used only when an addon requires a chart that is not available externally, or when a thin wrapper is useful to provide a Productive K3S-friendly installation experience.

Whenever possible, existing upstream charts should be reused instead of duplicated.

---

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

Contains tests for validating addons and examples.

Tests may include:

- smoke tests
- linting
- Helm template validation
- Kubernetes manifest validation
- installation checks against test clusters

## Relationship with other repositories

### `productive-k3s-core`

Provides the core runtime, installation logic, supported base addons, and cluster lifecycle.

This repository should not depend on `productive-k3s-addons`.

### `productive-k3s-infra`

Provides infrastructure automation, profiles, use cases, OpenTofu, Ansible, and environment-specific orchestration.

It may consume addons from this repository when useful.

### `productive-k3s-cli`

Provides the user-facing command line interface for installing and operating Productive K3S.

In the future, it may expose commands to discover or install addons.

## Status

This repository is currently a work in progress.

APIs, folder structure, conventions, and addon maturity levels may change.

## License

This project uses the same license as `productive-k3s-core`.

See [LICENSE](./LICENSE).
