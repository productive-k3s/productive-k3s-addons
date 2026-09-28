# geoserver-cloud

Installs a public GeoServer Cloud deployment for Productive K3S through the
Camptocamp Helm chart.

The default profile follows the upstream `pgconfig-acl` example: GeoServer Cloud
is installed as a multi-service topology, the catalog is stored in PostgreSQL
through `pgconfig`, and GeoServer ACL is enabled.

## Defaults

- Namespace: `geoserver`
- Helm release: `geoserver-cloud`
- Wrapper chart: `pk3s-geoserver-cloud`
- Upstream chart: `geoservercloud` `3.0.1`
- GeoServer Cloud image tag: `3.0.1.1`
- RabbitMQ image tag: `3.12.14-debian-12-r0`
- Spring profile: `standalone,pgconfig,acl`
- Hostname: `geoserver.k3s.lab.internal`
- Ingress: disabled unless `PK3S_GEOSERVER_INGRESS_ENABLED=y`
- Internal browser path: `/geoserver/web/`
- Default GeoServer user: `admin`
- Default GeoServer password: `geoserver`

The wrapper chart includes:

- GeoServer Cloud Gateway
- GeoServer Cloud Web UI
- GeoServer Cloud REST
- GeoServer Cloud WMS
- GeoServer Cloud WFS
- GeoServer Cloud GWC
- GeoServer ACL
- RabbitMQ
- PostGIS for the `pgconfig` catalog and ACL tables

This topology is meant for community validation and local/small cluster use. It
is not HA: PostGIS and RabbitMQ persistence are disabled by default so stack
verification can run on a disposable one-node Multipass cluster.

## Catalog And ACL Behavior

GeoServer Cloud runs with:

```text
SPRING_PROFILES_ACTIVE=standalone,pgconfig,acl
```

The catalog connection points at the release-local PostGIS service:

```text
PGCONFIG_HOST=geoserver-cloud-postgresql-hl
PGCONFIG_DATABASE=postgres
PGCONFIG_SCHEMA=pgconfig
PGCONFIG_USERNAME=postgres
```

ACL is enabled and points at:

```text
http://geoserver-cloud-gsc-acl:8080/acl/api
```

GWC is kept enabled because the GeoServer Cloud Web UI and OGC services expect
GeoWebCache beans during startup. Spring Cloud Bus is disabled in this community
verification profile because the current GeoServer Cloud images trigger the
known Spring AMQP anonymous queue declaration incompatibility around
`x-queue-leader-locator`. RabbitMQ remains part of the packaged topology so the
profile stays close to the upstream example.

The default passwords are intentionally simple for the public verification
profile. Override the wrapper values and enable durable storage before using
this topology outside disposable validation clusters.

## Operations

Status:

```bash
kubectl get pods -n geoserver
kubectl get svc -n geoserver
kubectl logs -n geoserver deploy/geoserver-cloud-gsc-gateway
kubectl get ingress -n geoserver
```

Port-forward browser access:

```bash
kubectl -n geoserver port-forward svc/geoserver-cloud-gsc-gateway 8080:8080
```

Then open:

```text
http://localhost:8080/geoserver/web/
```

Default credentials:

```text
admin / geoserver
```

## Upstream References

- Camptocamp `pgconfig-acl` example:
  `https://github.com/camptocamp/helm-geoserver-cloud/tree/master/examples/pgconfig-acl`
- Reference implementation used during Productive K3S alignment:
  `https://github.com/jemacchi/gscloud-in-nutshell`
