MAKEFILE_DIR := $(realpath $(dir $(firstword $(MAKEFILE_LIST))))

.DEFAULT_GOAL := help
.PHONY: help
help: ## Show this help
	@egrep -h '\s##\s' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

DOCKER_IMAGE := ansiblex
DOCKER_TAG := latest

.PHONY: build-%
build-%: ## Build the docker image
	docker build --platform linux/$* -t $(DOCKER_IMAGE):$(DOCKER_TAG) .
