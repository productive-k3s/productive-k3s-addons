.PHONY: help docs-build docs-serve docs-up docs-down docs-clean test-all test-matrix test-live-matrix test-live-matrix-ubuntu24

TESTS_DIR := ./tests
DOCS_DIR := ./docs

help:
	@echo "Productive K3S Addons"
	@echo ""
	@echo "Targets:"
	@echo "  make docs-build                             Build documentation"
	@echo "  make docs-serve                             Serve documentation in foreground"
	@echo "  make docs-up                                Serve documentation in background"
	@echo "  make docs-down                              Stop background documentation server"
	@echo "  make docs-clean                             Clean generated documentation state"
	@echo "  make test-all                               Run local non-live checks"
	@echo "  make test-matrix                            Run static + contract across all addons and stacks"
	@echo "  make test-live-matrix                       Run live validation for the base stack"
	@echo "  make test-live-matrix-ubuntu24              Run base stack live validation in a disposable Ubuntu 24.04 Multipass VM"
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

docs-up:
	$(MAKE) -C $(DOCS_DIR) docs-up

docs-down:
	$(MAKE) -C $(DOCS_DIR) docs-down

docs-clean:
	$(MAKE) -C $(DOCS_DIR) docs-clean

test-all:
	$(MAKE) -C $(TESTS_DIR) test-all

test-matrix:
	$(MAKE) -C $(TESTS_DIR) test-matrix

test-live-matrix:
	$(MAKE) -C $(TESTS_DIR) test-live-matrix

test-live-matrix-ubuntu24:
	$(MAKE) -C $(TESTS_DIR) test-live-matrix-ubuntu24
