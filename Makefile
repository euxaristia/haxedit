PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin

all: build

build:
	swift build -c release --static-swift-stdlib

test:
	swift test

install: build
	install -d $(BINDIR)
	install .build/release/HaxEdit $(BINDIR)/hexedit

local-install: build
	install -d $(HOME)/.local/bin
	install .build/release/HaxEdit $(HOME)/.local/bin/hexedit

clean:
	rm -rf .build

.PHONY: all build test install local-install clean
