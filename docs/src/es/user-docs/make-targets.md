# Targets de Make

Comandos de validación a nivel repositorio:

```bash
make validate-layout
make test-static ADDON=<name>
make test-contract ADDON=<name>
make test-live ADDON=<name> KUBECONFIG=~/.kube/config
make test-matrix
```

Para trabajo coordinado con un checkout no publicado de Core:

```bash
make test-matrix PRODUCTIVE_K3S_CORE_REPO_DIR=/ruta/a/productive-k3s-core
```
