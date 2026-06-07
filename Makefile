.PHONY: help test-static test-contract test-live test-matrix test-live-matrix validate-layout

SCRIPTS_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))/scripts

help:
	@echo "Productive K3S Addons"
	@echo ""
	@echo "Targets:"
	@echo "  make validate-layout                         Validate addon/stack source layout"
	@echo "  make test-static ADDON=<name>|STACK=<name>   Run repository static checks"
	@echo "  make test-contract ADDON=<name>|STACK=<name> Validate content against productive-k3s-core"
	@echo "  make test-live ADDON=<name>                  Install a packaged addon through productive-k3s-core"
	@echo "  make test-matrix                             Run static + contract across all addons and stacks"
	@echo "  make test-live-matrix                        Run live validation across discovered addons and stacks"

validate-layout:
	@bash $(SCRIPTS_DIR)/validate-addon-package.sh .

test-static:
	ADDON="$(ADDON)" STACK="$(STACK)" CORE_VERSION="$(CORE_VERSION)" PRODUCTIVE_K3S_CORE_REPO_DIR="$(PRODUCTIVE_K3S_CORE_REPO_DIR)" $(SCRIPTS_DIR)/productive-k3s-addons-dev.sh test-static

test-contract:
	ADDON="$(ADDON)" STACK="$(STACK)" CORE_VERSION="$(CORE_VERSION)" PRODUCTIVE_K3S_CORE_REPO_DIR="$(PRODUCTIVE_K3S_CORE_REPO_DIR)" $(SCRIPTS_DIR)/productive-k3s-addons-dev.sh test-contract

test-live:
	ADDON="$(ADDON)" STACK="$(STACK)" CORE_VERSION="$(CORE_VERSION)" PRODUCTIVE_K3S_CORE_REPO_DIR="$(PRODUCTIVE_K3S_CORE_REPO_DIR)" KUBECONFIG="$(KUBECONFIG)" PK3S_KUBE_CONTEXT="$(PK3S_KUBE_CONTEXT)" PK3S_ADDON_PUBLIC_HOST="$(PK3S_ADDON_PUBLIC_HOST)" $(SCRIPTS_DIR)/productive-k3s-addons-dev.sh test-live

test-matrix:
	CORE_VERSION="$(CORE_VERSION)" PRODUCTIVE_K3S_CORE_REPO_DIR="$(PRODUCTIVE_K3S_CORE_REPO_DIR)" $(SCRIPTS_DIR)/productive-k3s-addons-dev.sh test-matrix

test-live-matrix:
	CORE_VERSION="$(CORE_VERSION)" PRODUCTIVE_K3S_CORE_REPO_DIR="$(PRODUCTIVE_K3S_CORE_REPO_DIR)" KUBECONFIG="$(KUBECONFIG)" PK3S_KUBE_CONTEXT="$(PK3S_KUBE_CONTEXT)" PK3S_ADDON_PUBLIC_HOST="$(PK3S_ADDON_PUBLIC_HOST)" $(SCRIPTS_DIR)/productive-k3s-addons-dev.sh test-live-matrix
