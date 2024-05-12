MAKEFILE_DIR := $(realpath $(dir $(firstword $(MAKEFILE_LIST))))

.DEFAULT_GOAL := help
.PHONY: help
help: ## Show this help
	@egrep -h '\s##\s' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

DOCKER_IMAGE := getansible
DOCKER_TAG := latest

ANSIBLE_PLATFORM ?= arm64
ANSIBLE_RELEASE ?= 9.0
PYTHON_RELEASE ?= 20240415
PYTHON_VERSION ?= 3.11.9

.PHONY: lint
lint: ## Lint the code
	shellcheck getansible/*.sh pages/*.sh

.PHONY: run
run:  ## Build the docker image
	docker buildx build \
		--build-arg ANSIBLE_RELEASE=$(ANSIBLE_RELEASE) \
		--build-arg PYTHON_RELEASE=$(PYTHON_RELEASE) \
		--build-arg PYTHON_VERSION=$(PYTHON_VERSION) \
		--tag getansible:latest \
		--target build \
		$(MAKEFILE_DIR)/getansible
	docker run -it --rm getansible:latest

.PHONY: build
build:  ## Build the docker image
	docker buildx build \
		--build-arg ANSIBLE_RELEASE=$(ANSIBLE_RELEASE) \
		--build-arg PYTHON_RELEASE=$(PYTHON_RELEASE) \
		--build-arg PYTHON_VERSION=$(PYTHON_VERSION) \
		--output $(MAKEFILE_DIR)/dist \
		--platform linux/$(ANSIBLE_PLATFORM) \
		--progress=plain \
		$(MAKEFILE_DIR)/getansible

.PHONY: build-bats
build-bats:  ## Build the docker image for bats
	docker buildx build \
		--platform linux/$(ANSIBLE_PLATFORM) \
		--progress=plain \
		--tag bats:latest \
		$(MAKEFILE_DIR)/tests

.PHONY: shell
shell:
	docker run --rm \
		-v $(MAKEFILE_DIR)/dist/getansible-$(ANSIBLE_RELEASE)-$(ANSIBLE_PLATFORM).sh:/usr/local/bin/getansible.sh \
		debian:bookworm-slim

.PHONY: test
test:  ## Test getansible.sh
	docker run --rm \
		--platform linux/$(ANSIBLE_PLATFORM) \
		-v $(MAKEFILE_DIR)/dist/getansible-$(ANSIBLE_RELEASE)-$(ANSIBLE_PLATFORM).sh:/usr/local/bin/getansible.sh \
		-v $(MAKEFILE_DIR)/tests:/usr/src/bats \
		bats:latest --filter-tags !remote /usr/src/bats/

.PHONY: test-remote
test-remote:  ## Test getansible.sh
	docker run --rm \
		--platform linux/$(ANSIBLE_PLATFORM) \
		-v $(MAKEFILE_DIR)/tests:/usr/src/bats \
		bats:latest --filter-tags remote /usr/src/bats/

.PHONY: clean
clean:  ## Clean up
	rm -rf $(MAKEFILE_DIR)/dist
