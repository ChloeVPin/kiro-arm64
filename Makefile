# Kiro ARM64 — Makefile
#
# Convenience targets that wrap the staged build scripts.
# Each target is a thin wrapper around scripts/<NN>-*.sh; run scripts directly
# for finer control.

SHELL := /usr/bin/env bash
SCRIPTS := ./scripts

.DEFAULT_GOAL := help
.PHONY: help all prereqs fetch extract electron natives assemble icons deb \
        clean clean-soft clean-dist install uninstall reinstall verify

## help: Show this help
help:
	@printf "Kiro ARM64 build targets:\n\n"
	@awk '/^## / { sub(/^## /,""); printf "  \033[36m%-14s\033[0m %s\n", $$1, substr($$0, index($$0,$$2)) }' $(MAKEFILE_LIST)

## all: Run every build stage to produce the final .deb
all:
	@$(SCRIPTS)/build-all.sh

## prereqs: Install build dependencies (apt + node check)
prereqs:
	@$(SCRIPTS)/00-prereqs.sh

## fetch: Locate the upstream Kiro x64 source .deb
fetch:
	@$(SCRIPTS)/10-fetch-source.sh

## extract: Extract source .deb and detect Electron version
extract:
	@$(SCRIPTS)/20-extract-source.sh

## electron: Download arm64 Electron matching detected version
electron:
	@$(SCRIPTS)/30-fetch-electron.sh

## natives: Rebuild native node modules for arm64
natives:
	@$(SCRIPTS)/40-rebuild-natives.sh

## assemble: Combine Electron shell + app + native modules
assemble:
	@$(SCRIPTS)/50-assemble.sh

## icons: Generate PNG icons from assets/kiro-logo.svg
icons:
	@$(SCRIPTS)/60-generate-icons.sh

## deb: Build the final .deb package
deb:
	@$(SCRIPTS)/70-build-deb.sh

## verify: List arch of all .node binaries in the assembled app
verify:
	@find build/kiro-arm64/resources/app -name "*.node" -not -path "*/obj.target/*" \
	    -exec sh -c 'printf "%-90s %s\n" "$$1" "$$(file -b "$$1" | cut -d, -f1-2)"' _ {} \;

## install: Install the most recently built .deb (sudo)
install:
	@deb=$$(ls -t build/dist/*.deb 2>/dev/null | head -1); \
	  if [ -z "$$deb" ]; then echo "No .deb found. Run 'make deb' first."; exit 1; fi; \
	  echo "Installing $$deb"; \
	  sudo dpkg -i "$$deb"

## uninstall: Remove installed Kiro package (sudo)
uninstall:
	@sudo dpkg -r kiro

## reinstall: Uninstall + install the latest built .deb
reinstall: uninstall install

## clean: Remove the entire build/ directory
clean:
	@$(SCRIPTS)/clean.sh

## clean-soft: Clean build/ but keep downloads (electron zip, source deb)
clean-soft:
	@$(SCRIPTS)/clean.sh --soft

## clean-dist: Clean build/ but keep downloads/ and dist/
clean-dist:
	@$(SCRIPTS)/clean.sh --dist
