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
- `PK3S_REGISTRY_MANAGE_LOCAL_HOSTS`
- `PK3S_REGISTRY_TRUST_DOCKER`
- `PK3S_NODE_PRIMARY_IP`

Stack runtime metadata:

- `addon.yaml` declares the Core session values that are mapped into packaged
  stack installs.
- The registry password input is marked sensitive in metadata for runtimes that
  need to redact values in logs or events.
