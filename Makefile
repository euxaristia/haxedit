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

clean:
	rm -rf .build

.PHONY: all build test install clean
