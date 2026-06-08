# Tests y matriz

`productive-k3s-addons` valida contenido contra una versión elegida de `productive-k3s-core`.

Alcance default de CI:

- `static`
- `contract`

Alcance manual:

- `live`

Comandos típicos:

```bash
make test-static ADDON=nginx PRODUCTIVE_K3S_CORE_REPO_DIR=/ruta/a/productive-k3s-core
make test-contract STACK=base PRODUCTIVE_K3S_CORE_REPO_DIR=/ruta/a/productive-k3s-core
make test-live ADDON=nginx KUBECONFIG=~/.kube/config
make test-matrix PRODUCTIVE_K3S_CORE_REPO_DIR=/ruta/a/productive-k3s-core
```
