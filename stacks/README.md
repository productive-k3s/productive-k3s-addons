# Stacks

Each directory in `stacks/` is a publishable stack source package.

A stack is a declarative grouping of add-ons. It is not an add-on itself.

Minimum required file:

```text
stack.yaml
```

Suggested additional files:

- `README.md`
- environment-specific notes
- diagrams or platform references

Current transition rule:

- stack intent lives here
- add-on implementation belongs in `addons/`
- `productive-k3s-core` should move toward consuming external stack/add-on content rather than retaining embedded stack implementation

Current public stacks:

- `base`: core platform add-ons (`cert-manager`, `longhorn`, `rancher`, `registry`)
- `cluster-health`: read-only health and upgrade-readiness checks (`popeye`, `kubent`)
- `cluster-security`: vulnerability/configuration visibility plus policy auditing (`trivy-operator`, `kyverno`)
- `production-readiness`: operational and security readiness checks (`popeye`, `kubent`, `trivy-operator`, `kyverno`)
- `gitops`: GitOps platform (`cert-manager`, `argocd`)
- `database`: PostgreSQL platform (`longhorn`, `cloudnative-pg`)
- `geospatial`: GeoServer Cloud with chart-local PostGIS `pgconfig` and ACL (`geoserver-cloud`)
