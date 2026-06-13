# base Stack

Declarative source for the current Productive K3S base stack intent.

This stack is the externalized content counterpart of the platform shape that has historically been embedded inside `productive-k3s-core`.

Current referenced add-ons:

- `cert-manager`
- `longhorn`
- `rancher`
- `registry`

This stack definition is the first step of the split. The full runtime extraction remains incremental while Core compatibility is preserved.

Current contract notes:

- source delivery stays declarative and source-oriented with `spec.resolution.mode: catalog`
- published artifacts are expected to be promoted to bundled delivery by `productive-k3s-ops`
- runtime compatibility is currently declared for both `k3s` and `rke2`
