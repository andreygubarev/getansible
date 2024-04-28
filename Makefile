MAKEFILE_DIR := $(realpath $(dir $(firstword $(MAKEFILE_LIST))))

.DEFAULT_GOAL := help
.PHONY: help
help: ## Show this help
	@egrep -h '\s##\s' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

DOCKER_IMAGE := ansiblex
DOCKER_TAG := latest

ANSIBLE_CORE_VERSION ?= 2.16.6
PYTHON_RELEASE ?= 20240415
PYTHON_VERSION ?= 3.12.3

.PHONY: run
run:  ## Build the docker image
	docker build --target build -t ansiblex:latest \
		--build-arg ANSIBLE_CORE_VERSION=$(ANSIBLE_CORE_VERSION) \
		--build-arg PYTHON_RELEASE=$(PYTHON_RELEASE) \
		--build-arg PYTHON_VERSION=$(PYTHON_VERSION) \
	   $(MAKEFILE_DIR)/ansiblex
	docker run -it --rm ansiblex:latest

.PHONY: build-%
build-%:  ## Build the docker image
	docker buildx build --progress=plain --platform linux/$* -o $(MAKEFILE_DIR)/dist \
		--build-arg ANSIBLE_CORE_VERSION=$(ANSIBLE_CORE_VERSION) \
		--build-arg PYTHON_RELEASE=$(PYTHON_RELEASE) \
		--build-arg PYTHON_VERSION=$(PYTHON_VERSION) \
	   $(MAKEFILE_DIR)/ansiblex

.PHONY: build
build: build-amd64 build-arm64 ## Build ansiblex for amd64 and arm64

.PHONY: clean
clean:  ## Clean up
	rm -rf $(MAKEFILE_DIR)/dist
