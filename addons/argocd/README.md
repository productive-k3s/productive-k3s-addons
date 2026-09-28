# argocd

Installs Argo CD as a public Productive K3S GitOps add-on.

Longhorn is not required. The default install keeps Argo CD available inside the cluster; ingress can be enabled explicitly.

## Defaults

- Namespace: `argocd`
- Helm repository: `https://argoproj.github.io/argo-helm`
- Chart: `argo/argo-cd`
- Chart version: `10.8.1`
- Ingress: disabled unless `PK3S_ARGOCD_INGRESS_ENABLED=y`
- Hostname: `argocd.k3s.lab.internal`
- TLS source: existing secret/cert-manager path when ingress is enabled
- Default UI access: internal `argocd-server` Service; use port-forward unless
  ingress is enabled
- Default username: `admin`

## Configuration

- `PK3S_ARGOCD_CHART_VERSION`
- `PK3S_ARGOCD_HOST`
- `PK3S_ARGOCD_INGRESS_ENABLED`
- `PK3S_ARGOCD_TLS_ENABLED`
- `PK3S_ARGOCD_TLS_SECRET`
- `PK3S_INGRESS_CLASS_NAME`

If `PK3S_ARGOCD_ADMIN_PASSWORD_HASH` is set, it is passed to the chart as the initial admin password hash. Do not commit real password hashes into source.

When no admin password hash is provided, Argo CD generates the initial admin
password in the `argocd-initial-admin-secret` Secret:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

## Access

Default local access uses a port-forward:

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

Open:

```text
https://localhost:8080/
```

The browser may warn about the certificate because the default in-cluster path
uses Argo CD's generated TLS material. For a public cluster endpoint, enable
ingress and set the host/TLS environment variables before installation.

## Operations

Status:

```bash
kubectl get pods -n argocd
kubectl get svc,endpoints -n argocd
kubectl get ingress -n argocd
```

Cleanup removes the Helm release and namespace.
