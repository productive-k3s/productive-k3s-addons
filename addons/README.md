# Addons

Each directory in `addons/` is a publishable add-on source package.

Minimum required files:

```text
addon.yaml
scripts/install.sh
```

Suggested additional files:

- `README.md`
- `values.yaml`
- `charts/`
- `assets/`

Add-ons are intentionally independent from stacks. A stack may reference an add-on, but it does not replace the add-on package itself.

If an add-on wants to participate in the basic Core-managed public exposure flow, its `addon.yaml` should declare the minimal metadata needed for one host -> one service -> one port ingress mapping. That path is intended for the simplest public exposure use case only.

More advanced ingress behavior belongs in the add-on itself. Do not assume that `productive-k3s-core` will implement:

- path-based routing contracts
- custom TLS resources per add-on
- multiple public hosts
- arbitrary ingress annotations or middleware semantics

Those are valid add-on features, but they should live in the package logic and documentation.
