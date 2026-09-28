# rancher Addon

Productive K3S source package for installing Rancher through the upstream Helm chart.

This package expects cluster prerequisites to be handled externally:

- `cert-manager` must already exist for TLS-driven installs
- any referenced `ClusterIssuer` must already exist

Supported environment overrides:

- `PK3S_RANCHER_VERSION`
- `PK3S_RANCHER_HOST`
- `PK3S_RANCHER_BOOTSTRAP_PASSWORD`
- `PK3S_TLS_SOURCE` (`letsencrypt` or `secret`)
- `PK3S_CLUSTER_ISSUER`
- `PK3S_LETSENCRYPT_EMAIL`
- `PK3S_LETSENCRYPT_ENVIRONMENT`
- `PK3S_RANCHER_PRIVATE_CA`
- `PK3S_RANCHER_MANAGE_LOCAL_HOSTS`
- `PK3S_NODE_PRIMARY_IP`

Stack runtime metadata:

- `addon.yaml` declares the Core session values that are mapped into packaged
  stack installs.
- The bootstrap password input is marked sensitive in metadata for runtimes
  that need to redact values in logs or events.
