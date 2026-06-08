# Organización del proyecto

La estructura es:

```text
productive-k3s-addons/
├── addons/
├── stacks/
├── scripts/
├── tests/
└── docs/
```

Cada add-on publicable debe incluir:

- `addon.yaml`
- `scripts/configure.sh`
- `scripts/install.sh`
- `scripts/validate.sh`
- `scripts/clean.sh`
- `scripts/backup.sh`

Cada stack publicable debe incluir:

- `stack.yaml`

La metadata del add-on ahora también declara impacto de antemano:

- si cambia el estado del cluster
- si cambia el estado local del host
- qué capacidades host-locales puede usar
