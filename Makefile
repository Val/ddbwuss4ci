#!/usr/bin/env make
# vim: ft=make syn=make fileencoding=utf-8 sw=2 ts=2 ai eol et si
#
# Makefile:
#   Debian Docker Base With Unsecure SSH Server for Continuous Integration
#
# (c) 2018 Laurent Vallar <val@zbla.net>, MIT license see LICENSE file.

SHELL = /bin/bash
UNAME = $(shell uname)

REPO_DIR = $(shell basename ${PWD})

DEB_DIST ?= stretch
DEB_MIRROR_URL ?= http://deb.debian.org/debian
DEB_SECURITY_MIRROR_URL ?= http://security.debian.org
DEB_COMPONENTS ?= main
DEB_PACKAGES ?= openssh-server sudo

DOCKER_USER ?= admin
DOCKER_USER_UID ?= 1337
DOCKER_USER_GID ?= 1337

DOCKER_BUILD_TAG = vallar/${REPO_DIR}

HOSTNAME ?= ${REPO_DIR}

BUILD_ARGS = \
	--build-arg "DEB_COMPONENTS=${DEB_COMPONENTS}" \
	--build-arg "DEB_DIST=${DEB_DIST}" \
	--build-arg "DEB_MIRROR_URL=${DEB_MIRROR_URL}" \
	--build-arg "DEB_SECURITY_MIRROR_URL=${DEB_SECURITY_MIRROR_URL}" \
	--build-arg "DOCKER_USER=${DOCKER_USER}" \
	--build-arg "DOCKER_USER_UID=${DOCKER_USER_UID}" \
	--build-arg "DOCKER_USER_GID=${DOCKER_USER_GID}"

DOCKER_RUN_PREFIX = docker run --rm --name $(REPO_DIR) -h $(HOSTNAME)

ROOTSHELL = $(DOCKER_RUN_PREFIX) -ti -w /root $(DOCKER_BUILD_TAG) $(SHELL)
USERSHELL = $(DOCKER_RUN_PREFIX) -ti -w /home/$(DOCKER_USER) \
--user $(DOCKER_USER) $(DOCKER_BUILD_TAG) $(SHELL)

default: help

showenv: ## Show environment
	@echo '----------------------------------------------------------------------'
	@echo "BUILD_ARGS=${BUILD_ARGS}"
	@echo "DEB_COMPONENTS=${DEB_COMPONENTS}"
	@echo "DEB_DIST=${DEB_DIST}"
	@echo "DEB_MIRROR_URL=${DEB_MIRROR_URL}"
	@echo "DEB_PACKAGES=${DEB_PACKAGES}"
	@echo "DEB_SECURITY_MIRROR_URL=${DEB_SECURITY_MIRROR_URL}"
	@echo "DOCKER_BUILD_TAG=${DOCKER_BUILD_TAG}"
	@echo "DOCKER_RUN_PREFIX=${DOCKER_RUN_PREFIX}"
	@echo "DOCKER_USER=${DOCKER_USER}"
	@echo "DOCKER_USER_UID=${DOCKER_USER_UID}"
	@echo "DOCKER_USER_GID=${DOCKER_USER_GID}"
	@echo "DOCKER_USERNAME=${DOCKER_USERNAME}"
	@echo "HOSTNAME=${HOSTNAME}"
	@echo "REPO_DIR=${REPO_DIR}"
	@echo "SHELL=${SHELL}"
	@echo "UNAME=${UNAME}"
	@echo '----------------------------------------------------------------------'

help: ## Show this help
	@printf '\033[32mtargets:\033[0m\n'
	@grep -E '^[a-zA-Z _-]+:.*?## .*$$' $(MAKEFILE_LIST) |\
		sort |\
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n",$$1,$$2}'

clear-flag:
	if [ -f .$(FLAG) ]; then rm .$(FLAG); fi

build: .build ## Build image
.build: Dockerfile
	docker build --rm $(BUILD_ARGS) -t $(DOCKER_BUILD_TAG) \
		--cache-from $(DOCKER_BUILD_TAG):latest .
	touch .build

rmi: FLAG = build
rmi: clear-flag ## Remove image
	docker rmi -f $(DOCKER_BUILD_TAG)

rootshell: build ## Run root shell
	$(ROOTSHELL)

usershell: build ## Run user shell
	$(USERSHELL)

run: .run ## Run UNSECURE SSH Server
.run: build Makefile
	$(DOCKER_RUN_PREFIX) -d -P $(DOCKER_BUILD_TAG):latest
	touch .run

restart logs: ## Wrap 'docker <command>'
	docker $@ $(REPO_DIR)

stop rm: FLAG = run ## Wrap 'docker <command>'
stop rm: clear-flag
	docker $@ $(REPO_DIR)

tail: ## Tail container logs
	docker logs -f $(REPO_DIR)

login: ## Login to Docker hub
	@if [ -z "$$DOCKER_USERNAME" -o -z "$$DOCKER_PASSWORD" ]; then \
		echo '$$DOCKER_USERNAME **and** $$DOCKER_PASSWORD must be set'; \
		exit 2; \
	else \
		docker login -u="$$DOCKER_USERNAME" -p="$$DOCKER_PASSWORD"; \
	fi

pull: ## Run 'docker pull' with image
	docker pull $(DOCKER_BUILD_TAG):latest
	touch .build

push: ## Run 'docker push' with image
	docker push $(DOCKER_BUILD_TAG)
