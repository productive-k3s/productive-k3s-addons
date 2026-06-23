.PHONY: help docs-build docs-serve test-all test-matrix test-live-matrix

TESTS_DIR := ./tests
DOCS_DIR := ./docs

help:
	@echo "Productive K3S Addons"
	@echo ""
	@echo "Targets:"
	@echo "  make docs-build                             Build documentation"
	@echo "  make docs-serve                             Serve documentation in foreground"
	@echo "  make test-all                               Run local non-live checks"
	@echo "  make test-matrix                            Run static + contract across all addons and stacks"
	@echo "  make test-live-matrix                       Run live validation across discovered addons and stacks"
	@echo ""
	@echo "Detailed docs targets live under docs/:"
	@echo "  make -C docs docs-up | docs-down | docs-clean"
	@echo ""
	@echo "Detailed test targets live under tests/:"
	@echo "  make -C tests validate-layout"
	@echo "  make -C tests test-static ADDON=<name>|STACK=<name>"
	@echo "  make -C tests test-contract ADDON=<name>|STACK=<name>"
	@echo "  make -C tests test-live ADDON=<name>|STACK=<name>"

docs-build:
	$(MAKE) -C $(DOCS_DIR) docs-build

docs-serve:
	$(MAKE) -C $(DOCS_DIR) docs-serve

test-all:
	$(MAKE) -C $(TESTS_DIR) test-all

test-matrix:
	$(MAKE) -C $(TESTS_DIR) test-matrix

test-live-matrix:
	$(MAKE) -C $(TESTS_DIR) test-live-matrix
