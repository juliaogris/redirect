# Run `make help` to display help

# --- Global -------------------------------------------------------------------
O = out
COVERAGE = 33
VERSION ?= $(shell git describe --tags --dirty --always)

all: build test install check-coverage lint  ## build, test, check coverage and lint
	@if [ -e .git/rebase-merge ]; then git --no-pager log -1 --pretty='%h %s'; fi
	@echo '$(COLOUR_GREEN)Success$(COLOUR_NORMAL)'

ci: clean all  ## Full clean build and up-to-date checks as run on CI

clean::  ## Remove generated files
	-rm -rf $(O)

.PHONY: all ci clean

# --- Build --------------------------------------------------------------------
GO_LDFLAGS = -X main.version=$(VERSION)

build: | $(O)  ## Build reflect binaries
	go build -o $(O) -ldflags='$(GO_LDFLAGS)'

install:  ## Build and install binaries in $GOBIN
	go install -ldflags='$(GO_LDFLAGS)'

.PHONY: build install

# --- Test ---------------------------------------------------------------------
COVERFILE = $(O)/coverage.txt

test: ## Run tests and generate a coverage file
	go test -coverprofile=$(COVERFILE) ./...

check-coverage: test  ## Check that test coverage meets the required level
	@go tool cover -func=$(COVERFILE) | $(CHECK_COVERAGE) || $(FAIL_COVERAGE)

cover: test  ## Show test coverage in your browser
	go tool cover -html=$(COVERFILE)

CHECK_COVERAGE = awk -F '[ \t%]+' '/^total:/ {print; if ($$3 < $(COVERAGE)) exit 1}'
FAIL_COVERAGE = { echo '$(COLOUR_RED)FAIL - Coverage below $(COVERAGE)%$(COLOUR_NORMAL)'; exit 1; }

.PHONY: check-coverage cover test

# --- Lint ---------------------------------------------------------------------

lint:  ## Lint go source code
	golangci-lint run

.PHONY: lint

# --- Docker -------------------------------------------------------------------
docker-build:
	docker build \
		--build-arg=VERSION=$(VERSION) \
		--tag redirect:latest \
		.

docker-run: docker-build
	docker run --rm -it -p8080:8080 redirect:latest

.PHONY: docker-build docker-run

# --- Release -------------------------------------------------------------------
NEXTTAG := $(shell { git tag --list --merged HEAD --sort=-v:refname; echo v0.0.0; } | grep -E "^v?[0-9]+.[0-9]+.[0-9]+$$" | head -n1 | awk -F . '{ print $$1 "." $$2 "." $$3 + 1 }')
DOCKER_LOGIN = printenv DOCKER_PASSWORD | docker login --username "$(DOCKER_USERNAME)" --password-stdin

release: VERSION = $(NEXTTAG)
release: ## Tag and release binaries for different OS on GitHub release
	git tag $(VERSION)
	git push origin $(VERSION)
	goreleaser release --rm-dist
	[ -z "$(DOCKER_PASSWORD)" ] || $(DOCKER_LOGIN)
	docker buildx create –-use
	docker buildx build --push --build-arg=VERSION=$(VERSION) --tag julia/redirect:$(VERSION) --tag julia/redirect:latest --platform linux/amd64,linux/arm/v7 .

.PHONY: release

# --- Utilities ----------------------------------------------------------------
COLOUR_NORMAL = $(shell tput sgr0 2>/dev/null)
COLOUR_RED    = $(shell tput setaf 1 2>/dev/null)
COLOUR_GREEN  = $(shell tput setaf 2 2>/dev/null)
COLOUR_WHITE  = $(shell tput setaf 7 2>/dev/null)

help:
	@awk -F ':.*## ' 'NF == 2 && $$1 ~ /^[A-Za-z0-9%_-]+$$/ { printf "$(COLOUR_WHITE)%-25s$(COLOUR_NORMAL)%s\n", $$1, $$2}' $(MAKEFILE_LIST) | sort

$(O):
	@mkdir -p $@

.PHONY: help

define nl


endef
ifndef ACTIVE_HERMIT
$(eval $(subst \n,$(nl),$(shell bin/hermit env -r | sed 's/^\(.*\)$$/export \1\\n/')))
endif

# Ensure make version is gnu make 3.82 or higher
ifeq ($(filter undefine,$(value .FEATURES)),)
$(error Unsupported Make version. \
	$(nl)Use GNU Make 3.82 or higher (current: $(MAKE_VERSION)). \
	$(nl)Activate 🐚 hermit with `. bin/activate-hermit` and run again \
	$(nl)or use `bin/make`)
endif
