MAKEFILE_DIR := $(realpath $(dir $(firstword $(MAKEFILE_LIST))))

.DEFAULT_GOAL := help
.PHONY: help
help: ## Show this help
	@egrep -h '\s##\s' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

DOCKER_IMAGE := getansible
DOCKER_TAG := latest

ANSIBLE_VERSION ?= 9.0
PYTHON_RELEASE ?= 20240415
PYTHON_VERSION ?= 3.11.9

.PHONY: run
run:  ## Build the docker image
	docker build --target build -t getansible:latest \
		--build-arg ANSIBLE_VERSION=$(ANSIBLE_VERSION) \
		--build-arg PYTHON_RELEASE=$(PYTHON_RELEASE) \
		--build-arg PYTHON_VERSION=$(PYTHON_VERSION) \
	   $(MAKEFILE_DIR)/getansible
	docker run -it --rm getansible:latest

.PHONY: build-%
build-%:  ## Build the docker image
	docker buildx build --progress=plain --platform linux/$* -o $(MAKEFILE_DIR)/dist \
		--build-arg ANSIBLE_VERSION=$(ANSIBLE_VERSION) \
		--build-arg PYTHON_RELEASE=$(PYTHON_RELEASE) \
		--build-arg PYTHON_VERSION=$(PYTHON_VERSION) \
		--cache-to type=gha \
		--cache-from type=gha \
	   $(MAKEFILE_DIR)/getansible

.PHONY: build
build: build-amd64 build-arm64 ## Build getansible for amd64 and arm64

.PHONY: clean
clean:  ## Clean up
	rm -rf $(MAKEFILE_DIR)/dist
