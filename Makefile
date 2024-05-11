MAKEFILE_DIR := $(realpath $(dir $(firstword $(MAKEFILE_LIST))))

.DEFAULT_GOAL := help
.PHONY: help
help: ## Show this help
	@egrep -h '\s##\s' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

DOCKER_IMAGE := getansible
DOCKER_TAG := latest
DOCKER_PLATFORM ?= arm64

ANSIBLE_VERSION ?= 9.0
PYTHON_RELEASE ?= 20240415
PYTHON_VERSION ?= 3.11.9

.PHONY: lint
lint: ## Lint the code
	shellcheck getansible/*.sh pages/*

.PHONY: run
run:  ## Build the docker image
	docker buildx build \
		--build-arg ANSIBLE_VERSION=$(ANSIBLE_VERSION) \
		--build-arg PYTHON_RELEASE=$(PYTHON_RELEASE) \
		--build-arg PYTHON_VERSION=$(PYTHON_VERSION) \
		--tag getansible:latest \
		--target build \
		$(MAKEFILE_DIR)/getansible
	docker run -it --rm getansible:latest

.PHONY: build
build:  ## Build the docker image
	docker buildx build \
		--build-arg ANSIBLE_VERSION=$(ANSIBLE_VERSION) \
		--build-arg PYTHON_RELEASE=$(PYTHON_RELEASE) \
		--build-arg PYTHON_VERSION=$(PYTHON_VERSION) \
		--output $(MAKEFILE_DIR)/dist \
		--platform linux/$(DOCKER_PLATFORM) \
		--progress=plain \
		$(MAKEFILE_DIR)/getansible

.PHONY: shell
shell:
	docker run -it --rm \
		-v $(MAKEFILE_DIR)/dist/getansible-$(ANSIBLE_VERSION)-$(DOCKER_PLATFORM).sh:/usr/local/bin/getansible.sh \
		debian:bookworm-slim

.PHONY: test
test:  ## Test getansible.sh
	docker build -t getansible/bats:latest $(MAKEFILE_DIR)/tests
	docker run -it --rm \
		-v $(MAKEFILE_DIR)/dist/getansible-$(ANSIBLE_VERSION)-$(DOCKER_PLATFORM).sh:/usr/local/bin/getansible.sh \
		-v $(MAKEFILE_DIR)/tests:/usr/src/bats \
		getansible/bats:latest /usr/src/bats

.PHONY: clean
clean:  ## Clean up
	rm -rf $(MAKEFILE_DIR)/dist
