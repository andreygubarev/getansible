MAKEFILE_DIR := $(realpath $(dir $(firstword $(MAKEFILE_LIST))))

.DEFAULT_GOAL := help
.PHONY: help
help: ## Show this help
	@egrep -h '\s##\s' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

DOCKER_IMAGE := ansiblex
DOCKER_TAG := latest

.PHONY: build-%
build-%:  ## Build the docker image
	docker buildx build --progress=plain --platform linux/$* -o $(MAKEFILE_DIR)/dist $(MAKEFILE_DIR)/ansiblex

.PHONY: build
build: build-amd64 build-arm64 ## Build ansiblex for amd64 and arm64

.PHONY: clean
clean:  ## Clean up
	rm -rf $(MAKEFILE_DIR)/dist
