RUBY := /opt/homebrew/opt/ruby/bin/ruby
BUNDLE := $(dir $(RUBY))bundle
export PATH := $(dir $(RUBY)):$(PATH)

REMOTE := origin
BRANCH := gh-pages

.PHONY: serve build push install clean

serve:
	$(BUNDLE) exec jekyll serve --livereload

build:
	$(BUNDLE) exec jekyll build

push:
	git push $(REMOTE) master:$(BRANCH)

install:
	$(BUNDLE) install

clean:
	$(BUNDLE) exec jekyll clean
