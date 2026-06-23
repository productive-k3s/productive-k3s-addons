# longhorn Addon

Productive K3S source package for installing Longhorn through the upstream Helm chart.

Default behavior mirrors the current base stack defaults:

- chart version pinned by Productive K3S
- `defaultReplicaCount=1`
- `defaultDataPath=/data`

Supported environment overrides:

- `PK3S_LONGHORN_VERSION`
- `PK3S_LONGHORN_DATA_PATH`
- `PK3S_LONGHORN_REPLICA_COUNT`
- `PK3S_LONGHORN_SINGLE_NODE_MODE`
- `PK3S_LONGHORN_MINIMAL_AVAILABLE_PERCENTAGE`
