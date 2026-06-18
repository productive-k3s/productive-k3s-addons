SHELL := /bin/bash

DEV_WRAPPER := ../scripts/productive-k3s-addons-dev.sh
SCRIPTS_DIR := ../scripts

.PHONY: test-all test-all-raw test-static test-contract test-live test-matrix test-live-matrix validate-layout test-runtime-contract test-package-layout test-checkstatus-local test-checkstatus-matrix test-checkstatus-live test-clean-artifacts

validate-layout:
	bash $(SCRIPTS_DIR)/validate-addon-package.sh ..

test-all:
	bash $(DEV_WRAPPER) test-all

test-all-raw: validate-layout test-static test-contract

test-static:
	ADDON="$(ADDON)" STACK="$(STACK)" CORE_VERSION="$(CORE_VERSION)" PRODUCTIVE_K3S_CORE_REPO_DIR="$(PRODUCTIVE_K3S_CORE_REPO_DIR)" PRODUCTIVE_K3S_CORE_REPO_URL="$(PRODUCTIVE_K3S_CORE_REPO_URL)" PRODUCTIVE_K3S_CORE_REPO_REF="$(PRODUCTIVE_K3S_CORE_REPO_REF)" bash $(DEV_WRAPPER) test-static

test-contract:
	ADDON="$(ADDON)" STACK="$(STACK)" CORE_VERSION="$(CORE_VERSION)" PRODUCTIVE_K3S_CORE_REPO_DIR="$(PRODUCTIVE_K3S_CORE_REPO_DIR)" PRODUCTIVE_K3S_CORE_REPO_URL="$(PRODUCTIVE_K3S_CORE_REPO_URL)" PRODUCTIVE_K3S_CORE_REPO_REF="$(PRODUCTIVE_K3S_CORE_REPO_REF)" bash $(DEV_WRAPPER) test-contract

test-live:
	ADDON="$(ADDON)" STACK="$(STACK)" CORE_VERSION="$(CORE_VERSION)" PRODUCTIVE_K3S_CORE_REPO_DIR="$(PRODUCTIVE_K3S_CORE_REPO_DIR)" PRODUCTIVE_K3S_CORE_REPO_URL="$(PRODUCTIVE_K3S_CORE_REPO_URL)" PRODUCTIVE_K3S_CORE_REPO_REF="$(PRODUCTIVE_K3S_CORE_REPO_REF)" KUBECONFIG="$(KUBECONFIG)" PK3S_KUBE_CONTEXT="$(PK3S_KUBE_CONTEXT)" PK3S_ADDON_PUBLIC_HOST="$(PK3S_ADDON_PUBLIC_HOST)" bash $(DEV_WRAPPER) test-live

test-matrix:
	CORE_VERSION="$(CORE_VERSION)" PRODUCTIVE_K3S_CORE_REPO_DIR="$(PRODUCTIVE_K3S_CORE_REPO_DIR)" PRODUCTIVE_K3S_CORE_REPO_URL="$(PRODUCTIVE_K3S_CORE_REPO_URL)" PRODUCTIVE_K3S_CORE_REPO_REF="$(PRODUCTIVE_K3S_CORE_REPO_REF)" bash $(DEV_WRAPPER) test-matrix

test-live-matrix:
	CORE_VERSION="$(CORE_VERSION)" PRODUCTIVE_K3S_CORE_REPO_DIR="$(PRODUCTIVE_K3S_CORE_REPO_DIR)" PRODUCTIVE_K3S_CORE_REPO_URL="$(PRODUCTIVE_K3S_CORE_REPO_URL)" PRODUCTIVE_K3S_CORE_REPO_REF="$(PRODUCTIVE_K3S_CORE_REPO_REF)" KUBECONFIG="$(KUBECONFIG)" PK3S_KUBE_CONTEXT="$(PK3S_KUBE_CONTEXT)" PK3S_ADDON_PUBLIC_HOST="$(PK3S_ADDON_PUBLIC_HOST)" bash $(DEV_WRAPPER) test-live-matrix

test-runtime-contract:
	bash ./test-k8s-runtime-contract.sh

test-package-layout:
	PRODUCTIVE_K3S_CORE_REPO_DIR="$(PRODUCTIVE_K3S_CORE_REPO_DIR)" bash ./test-validate-addon-package.sh

test-checkstatus-local:
	bash $(DEV_WRAPPER) test-checkstatus-local

test-checkstatus-matrix:
	bash $(DEV_WRAPPER) test-checkstatus-matrix

test-checkstatus-live:
	bash $(DEV_WRAPPER) test-checkstatus-live

test-clean-artifacts:
	bash $(DEV_WRAPPER) test-clean-artifacts
