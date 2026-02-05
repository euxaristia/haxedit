PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
BUILD_DIR = .build/release
BINARY = $(BUILD_DIR)/HaxEdit

all: build

build:
	swift build -c release --static-swift-stdlib

test:
	swift test

install: $(BINARY)
	install -d $(BINDIR)
	install $(BINARY) $(BINDIR)/haxedit

local-install: $(BINARY)
	install -d $(HOME)/.local/bin
	install $(BINARY) $(HOME)/.local/bin/haxedit

uninstall:
	rm -f $(BINDIR)/haxedit

local-uninstall:
	rm -f $(HOME)/.local/bin/haxedit

$(BINARY):
	swift build -c release --static-swift-stdlib

clean:
	rm -rf .build

.PHONY: all build test install local-install uninstall local-uninstall clean
