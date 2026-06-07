# cert-manager Addon

Productive K3S source package for installing `cert-manager`.

Default behavior:

- applies the upstream release manifest pinned by Productive K3S
- waits for the namespace pods to become ready
- waits for webhook endpoints before returning success

Supported environment overrides:

- `PK3S_CERT_MANAGER_VERSION`
