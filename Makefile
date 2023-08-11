BINDIR = bin
SOURCEDIR = cmd
PACKAGEDIR = pkg

DIRS = $(shell find $(SOURCEDIR) -maxdepth 1 -mindepth 1 -type d)
SOURCES = $(shell find $(SOURCEDIR) -name '*.go' -type f)
OBJECTS = $(patsubst $(SOURCEDIR)/%, $(BINDIR)/%.wasm, $(DIRS))
PACKAGES = $(patsubst $(SOURCEDIR)/%, $(PACKAGEDIR)/%.tar.gz, $(DIRS))

mod:
	go mod tidy

build: mod $(OBJECTS)

package: build $(PACKAGES)

$(PACKAGEDIR)/%.tar.gz: $(BINDIR)/%.wasm
	@echo "Building package" $@
	@mkdir -p $(PACKAGEDIR)
	@mkdir -p /tmp/$(patsubst $(BINDIR)/%.wasm,%,$<)/bin
	@cp $< /tmp/$(patsubst $(BINDIR)/%.wasm,%,$<)/bin/main.wasm
	@cp configs/fastly/$(patsubst $(PACKAGEDIR)/%.tar.gz,%.toml,$@) /tmp/$(patsubst $(BINDIR)/%.wasm,%,$<)/fastly.toml
	tar -C /tmp/$(patsubst $(BINDIR)/%.wasm,%,$<)/ -cvzf $@ .

$(BINDIR)/%.wasm: $(SOURCEDIR)/%/main.go
	@mkdir -p $(BINDIR)
	tinygo build -target=wasi -gc=conservative -o $@ $<

clean:
	@rm -rvf compute/bin compute/pkg .terraform.lock.hcl

init:
	terraform init

plan-%: package init
	terraform plan -var "type=$*" -var "tld=jmoney.dev" -var "subdomain=echo" -var "websocket_backend=$(shell curl --silent "http://127.0.0.1:4040/api/tunnels" | jq -r '.tunnels[] | select(.name == "websocket") | .public_url')" -var "request_backend=$(shell curl --silent "http://127.0.0.1:4040/api/tunnels" | jq -r '.tunnels[] | select(.name == "request") | .public_url')"

apply-%: package init
	terraform apply -var "type=$*" -var "tld=jmoney.dev" -var "subdomain=echo" -var "websocket_backend=$(shell curl --silent "http://127.0.0.1:4040/api/tunnels" | jq -r '.tunnels[] | select(.name == "websocket") | .public_url')" -var "request_backend=$(shell curl --silent "http://127.0.0.1:4040/api/tunnels" | jq -r '.tunnels[] | select(.name == "request") | .public_url')" -auto-approve

destroy-%:
	terraform destroy -var "type=$*" -var "tld=jmoney.dev" -var "subdomain=echo" -var "websocket_backend=$(shell curl --silent "http://127.0.0.1:4040/api/tunnels" | jq -r '.tunnels[] | select(.name == "websocket") | .public_url')" -var "request_backend=$(shell curl --silent "http://127.0.0.1:4040/api/tunnels" | jq -r '.tunnels[] | select(.name == "request") | .public_url')" -auto-approve

