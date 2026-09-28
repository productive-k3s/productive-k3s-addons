# Tests y matriz

`productive-k3s-addons` valida contenido contra una versión elegida de `productive-k3s-core`.

Nota sobre nombres:

- `ADDON=nginx` y `STACK=base` seleccionan entradas del catálogo de este repositorio para validación
- no describen el contrato público de instalación de `core`
- la instalación pública de add-ons en `core` es artifact-first y espera `addon install --tgz <artifact>`

Alcance default de CI:

- `static`
- `contract`

Alcance manual:

- `live`

Comandos típicos:

```bash
make test-all PRODUCTIVE_K3S_CORE_REPO_DIR=/ruta/a/productive-k3s-core
make test-matrix PRODUCTIVE_K3S_CORE_REPO_DIR=/ruta/a/productive-k3s-core
make test-live-matrix PRODUCTIVE_K3S_CORE_REPO_DIR=/ruta/a/productive-k3s-core
make -C tests test-static ADDON=nginx PRODUCTIVE_K3S_CORE_REPO_DIR=/ruta/a/productive-k3s-core
make -C tests test-contract STACK=base PRODUCTIVE_K3S_CORE_REPO_DIR=/ruta/a/productive-k3s-core
make -C tests test-live ADDON=nginx KUBECONFIG=~/.kube/config
```
