HUGO ?= hugo

# Use Homebrew Hugo if not on PATH (e.g., inside a sandboxed shell).
ifeq (,$(shell command -v $(HUGO) 2>/dev/null))
  HUGO := /opt/homebrew/bin/hugo
endif

.PHONY: serve build deploy clean update-theme help

help:
	@echo "Targets:"
	@echo "  make serve         - run a local dev server with live reload"
	@echo "  make build         - produce a minified site under public/"
	@echo "  make deploy        - manually trigger the GitHub Actions deploy workflow"
	@echo "  make update-theme  - pull the latest hugo-book submodule"
	@echo "  make clean         - remove build artifacts"

serve:
	$(HUGO) server --buildDrafts --buildFuture --navigateToChanged

build:
	$(HUGO) --minify

# Deploys are handled by .github/workflows/deploy.yml on push to `site`.
# This target manually triggers a workflow run for the current branch.
deploy:
	gh workflow run deploy.yml --ref site

update-theme:
	git submodule update --remote --merge themes/hugo-book

clean:
	rm -rf public resources .hugo_build.lock
