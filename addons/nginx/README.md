# nginx Addon

Example public add-on package for Productive K3S.

This add-on installs the upstream Bitnami `nginx` chart through the packaged installer script.

## Immutable materials

The package pins Bitnami NGINX chart `25.2.1` and verifies the downloaded chart SHA256 before installation. The NGINX, Git helper, and NGINX Exporter images are declared with immutable multi-architecture digests in both `values.yaml` and `materials.lock.yaml`. Installation fails closed if the chart repository no longer serves the expected archive.

It also declares the basic Core-managed public ingress contract, so it can be exposed with:

```bash
pk3s addon install nginx --profile multipass-1-server-2-agents --public-host nginx-01.k3s.lab.internal
```

That contract is intentionally limited to one host routed to one service and port through Traefik.

It exists primarily as:

- a reference source package in `productive-k3s-addons`
- a packaging input for `productive-k3s-ops`
- a simple end-to-end artifact that `productive-k3s-core` can validate and install from `addon.tgz`
