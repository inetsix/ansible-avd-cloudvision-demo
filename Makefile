CONTAINER ?= avdteam/base:3.8-edge
VSCODE_CONTAINER ?= avdteam/vscode:latest
VSCODE_PORT ?= 8080
HOME_DIR = $(shell pwd)
AVD_COLLECTION_VERSION ?= 4.8.0
CVP_COLLECTION_VERSION ?= 3.10.1
ANSIBLE_ARGS ?=
ANSIBLE_VAULT_PASSWORD_FILE ?= ./.vault_passwd
HTTPS_PROXY ?=
PYTHON ?= python3

# This is lazy. Evaluated when used.
ARISTA_AVD_DIR=$(shell ansible-galaxy collection list arista.avd --format yaml |  grep $(AVD_COLLECTION_VERSION) -B2 | head -1 | cut -d: -f1)

help: ## Display help message
	@grep -E '^[0-9a-zA-Z_-]+\.*[0-9a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

################################################################################
# AVD Commands
################################################################################

.PHONY: build
build: ## Run ansible playbook to build EVPN Fabric configuration.
	ansible-playbook playbooks/dc1-fabric-deploy-cvp.yml --tags build $(ANSIBLE_ARGS)

.PHONY: provision
provision: ## Run ansible playbook to deploy EVPN Fabric.
	ansible-playbook playbooks/dc1-fabric-deploy-cvp.yml --tags provision $(ANSIBLE_ARGS)

.PHONY: deploy
deploy: ## Run ansible playbook to deploy EVPN Fabric.
	ansible-playbook playbooks/dc1-fabric-deploy-cvp.yml --extra-vars "execute_tasks=true" --tags "build,provision,apply" $(ANSIBLE_ARGS)

.PHONY: reset
reset: ## Run ansible playbook to reset all devices.
	ansible-playbook playbooks/dc1-fabric-reset-cvp.yml $(ANSIBLE_ARGS)

.PHONY: ztp
ztp: ## Configure ZTP server
	ansible-playbook playbooks/dc1-ztp-configuration.yml $(ANSIBLE_ARGS)

.PHONY: configlet-upload
configlet-upload: ## Upload configlets available in configlets/ to CVP.
	ansible-playbook playbooks/dc1-upload-configlets.yml $(ANSIBLE_ARGS)

.PHONY: install-git
install-git: ## Install Ansible collections from git
	git clone --depth 1 --branch v$(AVD_COLLECTION_VERSION) https://github.com/aristanetworks/ansible-avd.git
	git clone --depth 1 --branch v$(CVP_COLLECTION_VERSION) https://github.com/aristanetworks/ansible-cvp.git
	$(PYTHON) -m pip install -r ${ARISTA_AVD_DIR}/arista/avd/requirements.txt

.PHONY: install
install: ## Install Ansible collections
ifndef HTTPS_PROXY
	echo  installing requirements from: ${ARISTA_AVD_DIR}
	$(PYTHON) -m pip install ansible
	ansible-galaxy collection install arista.avd:==${AVD_COLLECTION_VERSION}
	ansible-galaxy collection install arista.cvp:==${CVP_COLLECTION_VERSION}
	$(PYTHON) -m pip install -r ${ARISTA_AVD_DIR}/arista/avd/requirements.txt
else
	echo  installing requirements from: ${ARISTA_AVD_DIR}
	HTTPS_PROXY=$(HTTPS_PROXY) $(PYTHON) -m pip install ansible
	HTTPS_PROXY=$(HTTPS_PROXY) ansible-galaxy collection install arista.avd:==${AVD_COLLECTION_VERSION}
	HTTPS_PROXY=$(HTTPS_PROXY) ansible-galaxy collection install arista.cvp:==${CVP_COLLECTION_VERSION}
	HTTPS_PROXY=$(HTTPS_PROXY) $(PYTHON) -m pip install -r ${ARISTA_AVD_DIR}/arista/avd/requirements.txt
endif

.PHONY: uninstall
uninstall: ## Remove collection from ansible
	rm -rf ansible-avd
	rm -rf ansible-cvp

.PHONY: webdoc
webdoc: ## Build documentation to publish static content
	mkdocs build -f mkdocs.yml

.PHONY: shell
shell: ## Start docker to get a preconfigured shell
	docker pull $(CONTAINER) && \
	docker run --rm -it \
		-v $(HOME_DIR)/:/projects \
		-v /etc/hosts:/etc/hosts $(CONTAINER)

.PHONY: vscode
vscode: ## Run a vscode server on port 8080
	docker run --rm -it -d \
		-e AVD_GIT_USER="$(git config --get user.name)" \
		-e AVD_GIT_EMAIL="$(git config --get user.email)" \
		-v $(HOME_DIR):/home/avd/ansible-avd-cloudvision-demo \
		-p $(VSCODE_PORT):8080 $(VSCODE_CONTAINER)
	@echo "---------------"
	@echo "VScode for AVD: http://127.0.0.1:$(VSCODE_PORT)/?folder=/home/avd/ansible-avd-cloudvision-demo"
