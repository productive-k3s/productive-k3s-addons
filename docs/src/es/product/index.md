# Producto

Este repositorio es la capa de paquetes curados para extender un cluster Productive K3S.

Usalo cuando quieras capacidades listas para usar dentro del cluster en lugar de ensamblar cada extensión a mano.

Los ejemplos incluyen paquetes relacionados con management, storage, ingress, registry, certificados y checks de salud de cluster de solo lectura.

`productive-k3s-core` sigue siendo la capa que instala y valida esos paquetes, mientras que `productive-k3s-addons` posee el catálogo público curado de addons y stacks.

El primer slice público de preparación operativa agrega:

- `popeye` para análisis de salud y configuración del cluster vivo
- `kubent` para detección de APIs Kubernetes deprecadas
- `cluster-health` como stack ordenado que ejecuta ambos checks

La expansión del backlog público también agrega:

- `trivy-operator` y `kyverno` para reportes y políticas en modo Audit
- `argocd` para entrega GitOps
- `cloudnative-pg` para operador PostgreSQL y clusters administrados
- `geoserver-cloud` para una ruta geoespacial respaldada por PostgreSQL
- stacks para `cluster-security`, `production-readiness`, `gitops`, `database` y `geospatial`
