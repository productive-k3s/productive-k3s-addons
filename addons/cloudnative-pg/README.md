# cloudnative-pg

Installs the CloudNativePG operator and can create a small PostgreSQL cluster.

The operator remains independently installable. The curated `database` and `geospatial` stacks use it as a dependency, but the add-on does not hard-code Longhorn.

## Defaults

- Operator namespace: `cnpg-system`
- Helm repository: `https://cloudnative-pg.github.io/charts`
- Chart: `cnpg/cloudnative-pg`
- Chart version: `0.29.0`
- Database namespace: `database`
- Cluster name: `pk3s-postgres`
- Database name: `app`
- Instances: `1`
- Storage size: `10Gi`
- StorageClass: unset, which lets Kubernetes use the cluster default

## Secret Contract

CloudNativePG creates application credentials as Kubernetes secrets. The default cluster exposes:

- namespace: `database`
- cluster: `pk3s-postgres`
- app secret: `pk3s-postgres-app`
- host: `pk3s-postgres-rw.database.svc.cluster.local`
- port: `5432`
- database: `app`

Consumers should reference the generated secret rather than copying credentials into source.

## Operations

Status:

```bash
kubectl get pods -n cnpg-system
kubectl -n cnpg-system rollout status deployment/cloudnative-pg
kubectl get clusters.postgresql.cnpg.io -n database
kubectl get secret pk3s-postgres-app -n database
```
