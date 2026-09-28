# gitops

Installs the public GitOps stack:

1. `cert-manager`
2. `argocd`

Argo CD ingress, TLS, hostname, and admin password hash remain configurable through the Argo CD add-on environment contract.

## Expected Behavior

- cert-manager runs in the `cert-manager` namespace and its webhook endpoint is
  populated before the stack is considered ready.
- Argo CD runs in the `argocd` namespace.
- `argocd-server` and `argocd-repo-server` are Deployments.
- `argocd-application-controller` is a StatefulSet.
- By default, Argo CD is reachable only through the in-cluster
  `argocd-server` service. Ingress is disabled unless explicitly enabled.

## Manual Checks

```bash
kubectl get pods -n cert-manager
kubectl get pods -n argocd
kubectl get svc,endpoints -n argocd
kubectl -n argocd rollout status deployment/argocd-server
kubectl -n argocd rollout status deployment/argocd-repo-server
kubectl -n argocd rollout status statefulset/argocd-application-controller
```

Default local access uses a port-forward:

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

Then open:

```text
https://localhost:8080/
```

The default username is `admin`. Unless `PK3S_ARGOCD_ADMIN_PASSWORD_HASH` was
provided at install time, read the generated initial password with:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```
