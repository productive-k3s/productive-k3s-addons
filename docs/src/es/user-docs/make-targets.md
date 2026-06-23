# Targets de Make

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

Para trabajo coordinado con un checkout no publicado de Core:

```bash
make test-matrix PRODUCTIVE_K3S_CORE_REPO_DIR=/ruta/a/productive-k3s-core
```
