.DEFAULT_GOAL := all

SRC_FILES := $(shell git ls-files --cached --others --exclude-standard | grep -E "\.go$$")
VERSION := 0.0.1
REVISION := $(shell git describe --always)

GO_BUILD_FLAGS := -v
GO_TEST_FLAGS := -v
GO_COVER_FLAGS := -coverpkg ./... -coverprofile coverage.txt -covermode atomic

#  Utils
#----------------------------------------------------------------
define section
  @printf "\e[34m--> $1\e[0m\n"
endef

#  dep
#----------------------------------------------------------------
DEP_BIN_DIR := ./vendor/.bin/
DEP_SRCS := \
	github.com/jessevdk/go-assets-builder

DEP_BINS := $(addprefix $(DEP_BIN_DIR),$(notdir $(DEP_SRCS)))

define dep-bin-tmpl
$(eval OUT := $(addprefix $(DEP_BIN_DIR),$(notdir $(1))))
$(OUT): dep
	$(call section,Installing $(OUT))
	@cd vendor/$(1) && GOBIN="$(shell pwd)/$(DEP_BIN_DIR)" go install .
endef

$(foreach src,$(DEP_SRCS),$(eval $(call dep-bin-tmpl,$(src))))


#  App
#----------------------------------------------------------------
BIN_DIR := ./bin/
GENERATED_BINS :=
CMDS := $(wildcard ./cmd/*)

define cmd-tmpl

$(eval NAME := $(notdir $(1)))
$(eval OUT := $(addprefix $(BIN_DIR),$(NAME)))
$(eval LDFLAGS := -ldflags "-X main.Name=$(NAME) -X main.Version=$(VERSION) -X main.Revision=$(REVISION)")
$(eval GENERATED_BINS += $(OUT))
$(OUT): $(SRC_FILES)
	$(call section,Building $(OUT))
	@go build $(GO_BUILD_FLAGS) $(LDFLAGS) -o $(OUT) $(1)

.PHONY: $(NAME)
$(NAME): $(OUT)
endef

$(foreach src,$(CMDS),$(eval $(call cmd-tmpl,$(src))))

.PHONY: all
all: $(GENERATED_BINS)


#  Commands
#----------------------------------------------------------------
.PHONY: setup
setup: dep $(DEP_BINS)

.PHONY: clean
clean:
	rm -rf $(BIN_DIR)/*

.PHONY: clobber
clobber: clean
	rm -rf vendor

.PHONY: dep
dep: Gopkg.toml Gopkg.lock
	$(call section,Installing dependencies)
	@dep ensure -v -vendor-only

.PHONY: gen
gen:
	@PATH=$(shell pwd)/$(DEP_BIN_DIR):$$PATH go generate ./...

.PHONY: lint
lint:
	$(call section,Linting)
	@gofmt -e -d -s $(SRC_FILES) | awk '{ e = 1; print $0 } END { if (e) exit(1) }'
	@echo $(SRC_FILES) | xargs -n1 golint -set_exit_status
	@go vet ./...

.PHONY: test
test:
	$(call section,Testing)
	@go test $(GO_TEST_FLAGS) ./...

.PHONY: cover
cover:
	$(call section,Testing with coverage)
	@go test $(GO_TEST_FLAGS) $(GO_COVER_FLAGS) ./...