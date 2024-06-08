MAKEFILE_DIR := $(realpath $(dir $(firstword $(MAKEFILE_LIST))))

.DEFAULT_GOAL := help
.PHONY: help
help: ## Show this help
	@egrep -h '\s##\s' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

DOCKER_IMAGE := getansible
DOCKER_TAG := latest

ANSIBLE_PLATFORM ?= arm64
ANSIBLE_RELEASE ?= 10.0
PYTHON_RELEASE ?= 20240415
PYTHON_VERSION ?= 3.11.9

BATS_TAGS ?= !install,!curlpipe

.PHONY: lint
lint: ## Lint the code
	shellcheck docs/*.sh src/*.sh

.PHONY: run
run:  ## Build the docker image
	docker buildx build \
		--build-arg ANSIBLE_RELEASE=$(ANSIBLE_RELEASE) \
		--build-arg PYTHON_RELEASE=$(PYTHON_RELEASE) \
		--build-arg PYTHON_VERSION=$(PYTHON_VERSION) \
		--tag getansible:latest \
		--target build \
		$(MAKEFILE_DIR)/src
	docker run -it --rm getansible:latest

.PHONY: build
build: ## Build using local environment
	cd $(MAKEFILE_DIR)/src && \
        ANSIBLE_RELEASE=$(ANSIBLE_RELEASE) \
        PYTHON_RELEASE=$(PYTHON_RELEASE) \
        PYTHON_VERSION=$(PYTHON_VERSION) \
        ./bin/build.sh

.PHONY: build
build-docker:  ## Build using docker
	docker buildx build \
		--build-arg ANSIBLE_RELEASE=$(ANSIBLE_RELEASE) \
		--build-arg PYTHON_RELEASE=$(PYTHON_RELEASE) \
		--build-arg PYTHON_VERSION=$(PYTHON_VERSION) \
		--output $(MAKEFILE_DIR)/src/dist \
		--platform linux/$(ANSIBLE_PLATFORM) \
		--progress=plain \
		$(MAKEFILE_DIR)/src

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
		-v $(MAKEFILE_DIR)/src/dist/getansible-$(ANSIBLE_RELEASE)-$(ANSIBLE_PLATFORM).sh:/usr/local/bin/getansible.sh \
		debian:bookworm-slim

.PHONY: test
test:  ## Test getansible.sh
	docker run --rm \
		--platform linux/$(ANSIBLE_PLATFORM) \
		-v $(MAKEFILE_DIR)/src/dist/getansible-$(ANSIBLE_RELEASE)-$(ANSIBLE_PLATFORM).sh:/usr/local/bin/getansible.sh \
		-v $(MAKEFILE_DIR)/tests:/usr/src/bats \
		bats:latest --filter-tags $(BATS_TAGS) /usr/src/bats/

.PHONY: test-install
test-install:  ## Test getansible.sh
	docker run --rm \
		-v $(MAKEFILE_DIR)/docs/install.sh:/usr/local/bin/install.sh \
		-v $(MAKEFILE_DIR)/tests:/usr/src/bats \
		bats:latest --filter-tags install /usr/src/bats/

.PHONY: test-curlpipe
test-curlpipe:  ## Test https://getansible.sh
	docker run --rm \
		-v $(MAKEFILE_DIR)/tests:/usr/src/bats \
		bats:latest --filter-tags curlpipe /usr/src/bats/

.PHONY: clean
clean:  ## Clean up
	rm -rf $(MAKEFILE_DIR)/src/dist
