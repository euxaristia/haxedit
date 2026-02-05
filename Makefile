PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
MANDIR ?= $(PREFIX)/share/man/man1
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
	install -d $(MANDIR)
	install -m 644 haxedit.1 $(MANDIR)/haxedit.1

local-install: $(BINARY)
	install -d $(HOME)/.local/bin
	install $(BINARY) $(HOME)/.local/bin/haxedit
	install -d $(HOME)/.local/share/man/man1
	install -m 644 haxedit.1 $(HOME)/.local/share/man/man1/haxedit.1

uninstall:
	rm -f $(BINDIR)/haxedit
	rm -f $(MANDIR)/haxedit.1

local-uninstall:
	rm -f $(HOME)/.local/bin/haxedit
	rm -f $(HOME)/.local/share/man/man1/haxedit.1

$(BINARY):
	swift build -c release --static-swift-stdlib

clean:
	rm -rf .build

.PHONY: all build test install local-install uninstall local-uninstall clean
