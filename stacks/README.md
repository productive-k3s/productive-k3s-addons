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
