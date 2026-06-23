# registry Addon

Productive K3S source package for installing the in-cluster registry used by the base stack.

This package creates:

- `registry` namespace
- `registry` deployment and service
- `registry-data` PVC
- `registry` ingress

Supported environment overrides:

- `PK3S_REGISTRY_IMAGE`
- `PK3S_REGISTRY_HOST`
- `PK3S_REGISTRY_PVC_SIZE`
- `PK3S_REGISTRY_STORAGE_CLASS`
- `PK3S_TLS_SOURCE`
- `PK3S_CLUSTER_ISSUER`
- `PK3S_REGISTRY_AUTH_ENABLED`
- `PK3S_REGISTRY_AUTH_USER`
- `PK3S_REGISTRY_AUTH_PASSWORD`
