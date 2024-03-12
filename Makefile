%:
	@echo ""

deps:
	go mod download
	go mod vendor
.PHONY: deps

build:
	php build.php
.PHONY: build