# Project layout

The repository structure is:

```text
productive-k3s-addons/
├── addons/
├── stacks/
├── scripts/
├── tests/
└── docs/
```

Each publishable add-on source must provide:

- `addon.yaml`
- `scripts/configure.sh`
- `scripts/install.sh`
- `scripts/validate.sh`
- `scripts/clean.sh`
- `scripts/backup.sh`

Each publishable stack source must provide:

- `stack.yaml`

Add-on metadata now also declares impact in advance:

- whether it changes cluster state
- whether it changes host-local state
- which host-local capabilities it may use
