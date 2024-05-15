BIN ?= archive
BRANCH = $(shell git branch --show-current)
ORIGIN = $(shell git remote get-url origin)
PREFIX ?= /usr/local
VERSION = $(shell git describe --tags --exact-match 2>/dev/null || git rev-parse HEAD)

install:
	@echo 'Installing archive.'
	cat './archive.sh' | sed "s/GIT_BRANCH=''/GIT_BRANCH='$(BRANCH)'/g" | sed "s|GIT_ORIGIN=''|GIT_ORIGIN='$(ORIGIN)'|g" | sed "s/GIT_VERSION=''/GIT_VERSION='$(VERSION)'/g" > '$(PREFIX)/bin/$(BIN)'
	chmod +x '$(PREFIX)/bin/$(BIN)'
	@echo 'Done installing archive as "$(PREFIX)/bin/$(BIN)".'

uninstall:
	@echo 'Uninstalling archive.'
	rm -f '$(PREFIX)/bin/$(BIN)'
	@echo 'Done uninstalling archive.'

.PHONY: install uninstall
