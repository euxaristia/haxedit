PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
MANDIR ?= $(PREFIX)/share/man/man1
HCC ?= hcc
BINARY ?= haxedit
HOLY_ENTRY := holy/haxedit.HC
HOLY_SOURCES := $(shell find holy -name "*.HC" 2>/dev/null)

all: build

build: $(BINARY)

test:
	@echo "No automated HolyC tests yet."
	@echo "Run smoke checks manually in a TTY."

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

$(BINARY): $(HOLY_SOURCES)
	@command -v $(HCC) >/dev/null 2>&1 || { echo "Error: $(HCC) not found in PATH"; exit 1; }
	$(HCC) -o $(BINARY) $(HOLY_ENTRY)

clean:
	rm -f $(BINARY)

.PHONY: all build test install local-install uninstall local-uninstall clean
