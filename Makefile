HUGO ?= hugo
REMOTE ?= origin
BRANCH ?= gh-pages

# Use Homebrew Hugo if not on PATH (e.g., inside a sandboxed shell).
ifeq (,$(shell command -v $(HUGO) 2>/dev/null))
  HUGO := /opt/homebrew/bin/hugo
endif

.PHONY: serve build deploy clean update-theme help

help:
	@echo "Targets:"
	@echo "  make serve         - run a local dev server with live reload"
	@echo "  make build         - produce a minified site under public/"
	@echo "  make deploy        - build and push public/ to $(BRANCH) on $(REMOTE)"
	@echo "  make update-theme  - pull the latest hugo-book submodule"
	@echo "  make clean         - remove build artifacts"

serve:
	$(HUGO) server --buildDrafts --buildFuture --navigateToChanged

build:
	$(HUGO) --minify

deploy: build
	./scripts/deploy.sh

update-theme:
	git submodule update --remote --merge themes/hugo-book

clean:
	rm -rf public resources .hugo_build.lock
