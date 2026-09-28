# geospatial

Installs the public geospatial application stack:

1. `geoserver-cloud`

`geoserver-cloud` is installed through the Camptocamp Helm chart with the
`standalone,pgconfig,acl` profile. The stack exposes GeoServer Cloud through the
Gateway service, stores the GeoServer catalog in PostgreSQL through `pgconfig`,
and enables GeoServer ACL.

## Components

- GeoServer Cloud Gateway
- GeoServer Cloud Web UI
- GeoServer Cloud REST
- GeoServer Cloud WMS
- GeoServer Cloud WFS
- GeoServer Cloud GWC
- GeoServer ACL
- RabbitMQ
- PostGIS for catalog and ACL state

## Defaults

- Namespace: `geoserver`
- Release: `geoserver-cloud`
- Internal Gateway service: `geoserver-cloud-gsc-gateway`
- Browser path: `/geoserver/web/`
- Default user: `admin`
- Default password: `geoserver`

The community verification profile disables PostGIS and RabbitMQ persistence
so the stack can be exercised cheaply on disposable one-node Multipass clusters.
Do not treat those defaults as production storage settings.

GWC remains enabled in this profile because the GeoServer Cloud Web UI and OGC
services expect GeoWebCache support during startup. Spring Cloud Bus is disabled
for community verification to avoid the current Spring AMQP anonymous queue
declaration issue around `x-queue-leader-locator`.
