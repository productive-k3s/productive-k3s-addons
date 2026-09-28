# Objetivos De Make

Estos comandos son principalmente para validación y mantenimiento del repositorio, no para la primera comprensión a nivel producto del catálogo de addons.

Comandos de validación a nivel repositorio:

```bash
make test-all
make test-matrix
make test-live-matrix
```

Los targets detallados de test viven en `tests/`:

```bash
make -C tests validate-layout
make -C tests test-static ADDON=<name>
make -C tests test-contract ADDON=<name>
make -C tests test-live ADDON=<name> KUBECONFIG=~/.kube/config
```

Acá `ADDON=<name>` funciona como selector del catálogo para validación dentro del repositorio. No significa que `productive-k3s-core` instale add-ons públicos por nombre de fuente. El camino público de `core` sigue siendo package-first con `addon install --tgz <artifact>`.

Para trabajo coordinado con un checkout no publicado de Core:

```bash
make test-matrix PRODUCTIVE_K3S_CORE_REPO_DIR=/ruta/a/productive-k3s-core
```
