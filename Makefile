# Makefile for Tenrec Terminal
# Provides common developer tasks for building, testing, and running the app

SCHEME = "Tenrec Terminal"
CONFIGURATION = Debug
DERIVED_DATA_PATH = build

.PHONY: help build test run clean

help:
	@echo "Tenrec Terminal - Available targets:"
	@echo "  make build       - Build the application (Debug)"
	@echo "  make test        - Run all tests (unit + UI)"
	@echo "  make run         - Build and launch the application"
	@echo "  make clean       - Clean build artifacts"

build:
	xcodebuild -scheme $(SCHEME) -configuration $(CONFIGURATION) build

test:
	xcodebuild test -scheme $(SCHEME)

run: build
	@echo "Launching Tenrec Terminal..."
	@open "$(DERIVED_DATA_PATH)/Build/Products/$(CONFIGURATION)/Tenrec Terminal.app" || \
		open "$$(xcodebuild -scheme $(SCHEME) -configuration $(CONFIGURATION) -showBuildSettings | grep -m 1 "BUILT_PRODUCTS_DIR" | sed 's/.*= //')/Tenrec Terminal.app"

clean:
	xcodebuild -scheme $(SCHEME) clean
	rm -rf $(DERIVED_DATA_PATH)
