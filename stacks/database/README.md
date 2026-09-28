# database

Installs the public PostgreSQL platform stack:

1. `longhorn`
2. `cloudnative-pg`

The curated stack selects Longhorn first, but the CloudNativePG add-on itself can use any selected/default StorageClass.

## Validated Behavior

The single-node stack verification path validates this stack through the public
`pk3s` CLI on a disposable Multipass VM.

Expected runtime state:

- Longhorn components run in `longhorn-system`.
- `longhorn-single` is the default StorageClass for single-node verification.
- CloudNativePG operator runs as `deployment/cloudnative-pg` in `cnpg-system`.
- PostgreSQL cluster `database/pk3s-postgres` reaches `Cluster in healthy state`.
- Service `database/pk3s-postgres-rw` has endpoints.
- Secret `database/pk3s-postgres-app` contains generated application
  credentials.
- A `psql` probe can connect to database `app` through the read-write service.

## Manual Checks

```bash
kubectl get pods -n longhorn-system
kubectl get storageclass
kubectl -n cnpg-system rollout status deployment/cloudnative-pg
kubectl get clusters.postgresql.cnpg.io -n database
kubectl get pods,svc,secrets -n database
```

Read the generated application credentials:

```bash
kubectl -n database get secret pk3s-postgres-app -o jsonpath='{.data.username}' | base64 -d
kubectl -n database get secret pk3s-postgres-app -o jsonpath='{.data.password}' | base64 -d
```
