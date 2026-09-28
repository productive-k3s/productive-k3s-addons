# Product

This repository is the curated package layer for extending a Productive K3S cluster.

Use it when you want ready-to-use cluster capabilities rather than assembling every extension by hand.

Examples include management, storage, ingress, registry, certificate-related packages, and read-only cluster health checks.

`productive-k3s-core` remains the layer that installs and validates those packages, while `productive-k3s-addons` owns the curated public catalog of add-ons and stacks.

The contract boundary matters:

- this repository names and validates catalog entries such as `nginx` or `base`
- public `core` add-on installation consumes packaged artifacts rather than resolving add-on source names directly

The first public operations-readiness slice adds:

- `popeye` for live cluster health and configuration analysis
- `kubent` for deprecated Kubernetes API detection
- `cluster-health` as the ordered stack that runs both checks

The expanded public backlog also adds:

- `trivy-operator` and `kyverno` for reporting and audit-mode policy visibility
- `argocd` for GitOps delivery
- `cloudnative-pg` for PostgreSQL operator and managed clusters
- `geoserver-cloud` for a PostgreSQL-backed geospatial application path
- stacks for `cluster-security`, `production-readiness`, `gitops`, `database`, and `geospatial`
