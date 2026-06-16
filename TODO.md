# TODO

Simple, versioned backlog for `productive-k3s-addons` only.

Format:
- `Title`: short action-oriented label
- `Description`: one sentence, max 250 chars, easy to scan in reviews

Rules:
- Keep only repo-local responsibilities here.
- Do not track work owned by other repositories.
- Cross-repo dependencies can be mentioned only as context, never as the main ownership of an item.

## Stack and Addon Source Contracts

- `Apply Runtime Compatibility Metadata to More Stacks`
  `Adopt the same stack contract used by base for future stacks, including explicit resolution intent and runtime compatibility metadata.`

- `Review Addon Source Contracts`
  `Verify that packaged addons expose the metadata and scripts expected by Core, especially for configure, install, validate, and cleanup flows.`

- `Document Source vs Artifact Semantics`
  `Clarify in repo docs that this repository owns source content, while packaged addon and stack artifacts are generated and published elsewhere.`

## Content Validation

- `Add Stack Source Validation Helpers`
  `Provide simple repo-local validation helpers so broken stack manifests or duplicate addon references are caught before packaging time.`

- `Centralize GitHub Owner and Core Release Source`
  `Replace hardcoded jemacchi URLs with repo-local defaults in tests/common.sh and docs/mkdocs.yml so Core release lookup and repo links do not depend on a personal namespace.`

- `Review Public Exposure Metadata`
  `Check that addons using the basic public exposure contract declare service, namespace, and port metadata consistently.`

- `Identify Example vs Supported Content`
  `Mark which addons and stacks are intended as supported public references versus illustrative examples that may evolve more freely.`
