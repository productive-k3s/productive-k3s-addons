# Productive K3S Addons Documentation Workspace

This directory contains the MkDocs workspace for the public `productive-k3s-addons` documentation site.

## Layout

```text
docs/
├── build.sh
├── serve.sh
├── clean.sh
├── requirements.txt
├── mkdocs.yml
└── src/
    ├── index.md
    ├── assets/
    ├── overrides/
    ├── en/
    └── es/
```

## Local workflow

Build the site:

```bash
./docs/build.sh
make docs-build
make -C docs docs-build
```

Serve the site locally:

```bash
./docs/serve.sh
make docs-serve
make -C docs docs-serve
```

Background mode:

```bash
make -C docs docs-up
make -C docs docs-down
```

Full cleanup:

```bash
./docs/clean.sh
make -C docs docs-clean
```
