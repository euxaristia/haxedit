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
	@$(MAKE) smoke

smoke: $(BINARY)
	@command -v script >/dev/null 2>&1 || { echo "Error: script(1) not found"; exit 1; }
	@command -v strings >/dev/null 2>&1 || { echo "Error: strings(1) not found"; exit 1; }
	@command -v rg >/dev/null 2>&1 || { echo "Error: rg not found"; exit 1; }
	@./$(BINARY) --help | rg -q -- "^usage: haxedit \\[options\\] <file>$$" || { echo "Smoke failed: --help output mismatch"; exit 1; }
	@bash -lc './$(BINARY) /tmp/definitely-missing-haxedit-file.bin >/tmp/haxedit-no-file.out 2>&1; test $$? -ne 0' || { echo "Smoke failed: missing file should fail"; exit 1; }
	@rg -q -- "cannot open file" /tmp/haxedit-no-file.out || { echo "Smoke failed: missing file error text mismatch"; exit 1; }
	@bash -lc './$(BINARY) --linelength 5000 >/tmp/haxedit-ll-bad.out 2>&1; test $$? -ne 0' || { echo "Smoke failed: invalid --linelength should fail"; exit 1; }
	@rg -q -- "invalid line length" /tmp/haxedit-ll-bad.out || { echo "Smoke failed: invalid --linelength missing error text"; exit 1; }
	@bash -lc './$(BINARY) -l-1 >/tmp/haxedit-ll-neg.out 2>&1; test $$? -ne 0' || { echo "Smoke failed: negative -l should fail"; exit 1; }
	@rg -q -- "invalid line length" /tmp/haxedit-ll-neg.out || { echo "Smoke failed: negative -l missing error text"; exit 1; }
	@printf '\x00\x11\x22\x33\x44\x55\x66\x77\x88\x99\xaa\xbb\xcc\xdd\xee\xff' > /tmp/haxedit-smoke.bin
	@timeout 0.4 ./$(BINARY) -l1 /tmp/haxedit-smoke.bin >/dev/null 2>/dev/null; code=$$?; [ "$$code" -eq 124 ] || { echo "Smoke failed: -l1 should be accepted"; exit 1; }
	@cp /tmp/haxedit-smoke.bin /tmp/haxedit-readonly.bin
	@bash -lc '{ printf "f"; sleep 0.15; printf "\027"; sleep 0.15; printf "\003"; } | script -q -c "./$(BINARY) -r /tmp/haxedit-readonly.bin" /tmp/haxedit-readonly.log' >/dev/null
	@xxd -p -l 1 /tmp/haxedit-readonly.bin | rg -q -- "^00$$" || { echo "Smoke failed: readonly mode allowed byte edit"; exit 1; }
	@cp /tmp/haxedit-smoke.bin /tmp/haxedit-open-dirty.bin
	@bash -lc '{ printf "f"; sleep 0.15; printf "\017"; sleep 0.15; printf "c\r"; sleep 0.15; printf "\030"; } | script -q -c "./$(BINARY) /tmp/haxedit-open-dirty.bin" /tmp/haxedit-open-dirty.log' >/dev/null
	@xxd -p -l 1 /tmp/haxedit-open-dirty.bin | rg -q -- "^f0$$" || { echo "Smoke failed: Ctrl+O dirty-cancel path lost pending edit"; exit 1; }
	@cp /tmp/haxedit-smoke.bin /tmp/haxedit-open-save-a.bin
	@dd if=/dev/zero of=/tmp/haxedit-open-save-b.bin bs=1 count=32 status=none
	@bash -lc '{ printf "f"; sleep 0.15; printf "\017"; sleep 0.15; printf "y\r"; sleep 0.15; printf "/tmp/haxedit-open-save-b.bin\r"; sleep 0.2; printf ">"; sleep 0.15; printf "\003"; } | script -q -c "./$(BINARY) /tmp/haxedit-open-save-a.bin" /tmp/haxedit-open-save.log' >/dev/null
	@xxd -p -l 1 /tmp/haxedit-open-save-a.bin | rg -q -- "^f0$$" || { echo "Smoke failed: dirty Ctrl+O save-yes path did not save original file"; exit 1; }
	@strings /tmp/haxedit-open-save.log | rg -q -- "--0x20/0x20--100%" || { echo "Smoke failed: dirty Ctrl+O save-yes path did not switch to new file"; exit 1; }
	@cp /tmp/haxedit-smoke.bin /tmp/haxedit-clip-a.bin
	@dd if=/dev/zero of=/tmp/haxedit-clip-b.bin bs=1 count=16 status=none
	@bash -lc '{ printf "\006"; sleep 0.1; printf "v"; sleep 0.1; printf "\006"; sleep 0.1; printf "\004"; sleep 0.1; printf "\017"; sleep 0.1; printf "/tmp/haxedit-clip-b.bin\r"; sleep 0.2; printf "\031"; sleep 0.1; printf "\030"; } | script -q -c "./$(BINARY) /tmp/haxedit-clip-a.bin" /tmp/haxedit-clip-open.log' >/dev/null
	@xxd -p -l 1 /tmp/haxedit-clip-b.bin | rg -q -- "^11$$" || { echo "Smoke failed: clipboard was not preserved across Ctrl+O open-file"; exit 1; }
	@cp /tmp/haxedit-smoke.bin /tmp/haxedit-quit-confirm.bin
	@bash -lc '{ printf "f"; sleep 0.15; printf "\003"; sleep 0.15; printf "\003"; } | script -q -c "./$(BINARY) /tmp/haxedit-quit-confirm.bin" /tmp/haxedit-quit-confirm.log' >/dev/null
	@xxd -p -l 1 /tmp/haxedit-quit-confirm.bin | rg -q -- "^00$$" || { echo "Smoke failed: dirty Ctrl+C quit-confirm flow unexpectedly saved edits"; exit 1; }
	@cp /tmp/haxedit-smoke.bin /tmp/haxedit-save-quit.bin
	@bash -lc '{ printf "f"; sleep 0.15; printf "\030"; } | script -q -c "./$(BINARY) /tmp/haxedit-save-quit.bin" /tmp/haxedit-save-quit.log' >/dev/null
	@xxd -p -l 1 /tmp/haxedit-save-quit.bin | rg -q -- "^f0$$" || { echo "Smoke failed: Ctrl+X save+quit did not persist edit"; exit 1; }
	@timeout 0.4 ./$(BINARY) --linelength 0 /tmp/haxedit-smoke.bin >/dev/null 2>/dev/null; code=$$?; [ "$$code" -eq 124 ] || { echo "Smoke failed: --linelength 0 should enter editor (auto mode)"; exit 1; }
	@cp /tmp/haxedit-smoke.bin /tmp/-haxedit-smoke.bin
	@bash -lc '{ sleep 0.15; printf "\003"; } | script -q -c "./$(BINARY) -- /tmp/-haxedit-smoke.bin" /tmp/haxedit-dashfile.log' >/dev/null
	@strings /tmp/haxedit-dashfile.log | rg -q -- "--0x0/0x10--0%" || { echo "Smoke failed: -- terminator did not open dash-prefixed file"; exit 1; }
	@dd if=/dev/zero of=/tmp/haxedit-sector.bin bs=1 count=2048 status=none
	@bash -lc '{ printf ">"; sleep 0.15; printf "<"; sleep 0.15; printf "G"; sleep 0.15; printf "\r0x3\r"; sleep 0.2; printf "\003"; } | script -q -c "./$(BINARY) /tmp/haxedit-smoke.bin" /tmp/haxedit-smoke.log' >/dev/null
	@strings /tmp/haxedit-smoke.log | rg -q -- "--0x10/0x10--100%" || { echo "Smoke failed: missing end-of-file cursor state for > or G"; exit 1; }
	@strings /tmp/haxedit-smoke.log | rg -q -- "--0x0/0x10--0%" || { echo "Smoke failed: missing start-of-file cursor state for <"; exit 1; }
	@strings /tmp/haxedit-smoke.log | rg -q -- "goto offset:" || { echo "Smoke failed: goto offset prompt not shown"; exit 1; }
	@strings /tmp/haxedit-smoke.log | rg -q -- "--0x3/0x10--20%" || { echo "Smoke failed: goto offset did not land on 0x3"; exit 1; }
	@cp /tmp/haxedit-smoke.bin /tmp/haxedit-sel-inclusive.bin
	@bash -lc '{ printf "v"; sleep 0.1; printf "\006"; sleep 0.1; printf "\004"; sleep 0.1; printf ">"; sleep 0.1; printf "\031"; sleep 0.1; printf "\030"; } | script -q -c "./$(BINARY) /tmp/haxedit-sel-inclusive.bin" /tmp/haxedit-sel-inclusive.log' >/dev/null
	@stat -c%s /tmp/haxedit-sel-inclusive.bin | rg -q -- "^18$$" || { echo "Smoke failed: selection copy was not endpoint-inclusive (size mismatch)"; exit 1; }
	@xxd -p /tmp/haxedit-sel-inclusive.bin | tr -d '\n' | rg -q -- "0011$$" || { echo "Smoke failed: selection did not include both endpoints"; exit 1; }
	@bash -lc '{ printf "/"; sleep 0.1; printf "33\r"; sleep 0.2; printf "\003"; } | script -q -c "./$(BINARY) /tmp/haxedit-smoke.bin" /tmp/haxedit-search-fwd.log' >/dev/null
	@strings /tmp/haxedit-search-fwd.log | rg -q -- "--0x3/0x10--20%" || { echo "Smoke failed: forward search did not land on expected offset"; exit 1; }
	@bash -lc '{ printf ">"; sleep 0.1; printf "\022"; sleep 0.1; printf "11\r"; sleep 0.2; printf "\003"; } | script -q -c "./$(BINARY) /tmp/haxedit-smoke.bin" /tmp/haxedit-search-rev.log' >/dev/null
	@strings /tmp/haxedit-search-rev.log | rg -q -- "--0x1/0x10--6%" || { echo "Smoke failed: reverse search did not land on expected offset"; exit 1; }
	@bash -lc '{ printf "\r0x3\r"; sleep 0.1; printf "/"; sleep 0.1; printf "0\r"; sleep 0.2; printf "\003"; } | script -q -c "./$(BINARY) /tmp/haxedit-smoke.bin" /tmp/haxedit-search-invalid.log' >/dev/null
	@strings /tmp/haxedit-search-invalid.log | rg -q -- "--0x3/0x10--20%" || { echo "Smoke failed: invalid search pattern changed cursor unexpectedly"; exit 1; }
	@cp /tmp/haxedit-smoke.bin /tmp/haxedit-trunc-invalid.bin
	@bash -lc '{ printf "\033t"; sleep 0.1; printf "xyz\r"; sleep 0.2; printf "\030"; } | script -q -c "./$(BINARY) /tmp/haxedit-trunc-invalid.bin" /tmp/haxedit-trunc-invalid.log' >/dev/null
	@stat -c%s /tmp/haxedit-trunc-invalid.bin | rg -q -- "^16$$" || { echo "Smoke failed: invalid truncate input changed file size"; exit 1; }
	@xxd -p -l 2 /tmp/haxedit-trunc-invalid.bin | rg -q -- "^0011$$" || { echo "Smoke failed: invalid truncate input changed file contents"; exit 1; }
	@cp /tmp/haxedit-smoke.bin /tmp/haxedit-clip-fail.bin
	@bash -lc '{ printf "\006"; sleep 0.1; printf "v"; sleep 0.1; printf "\006"; sleep 0.1; printf "\033[99;6u"; sleep 0.2; printf "\003"; } | script -q -c "env HAXEDIT_TEST_CLIPBOARD_FAIL=1 ./$(BINARY) /tmp/haxedit-clip-fail.bin" /tmp/haxedit-clip-fail.log' >/dev/null
	@xxd -p -l 2 /tmp/haxedit-clip-fail.bin | rg -q -- "^0011$$" || { echo "Smoke failed: system clipboard failure path caused unexpected data mutation"; exit 1; }
	@bash -lc '{ printf "\033[1;3C"; sleep 0.15; printf "\033[1;3C"; sleep 0.15; printf "\033[104;7u"; sleep 0.2; printf "\003"; sleep 0.1; printf "\003"; } | script -q -c "./$(BINARY) /tmp/haxedit-smoke.bin" /tmp/haxedit-modkeys.log' >/dev/null
	@strings /tmp/haxedit-modkeys.log | rg -q -- "--0x4/0x10--26%" || { echo "Smoke failed: CSI Alt+Right did not move by block"; exit 1; }
	@strings /tmp/haxedit-modkeys.log | rg -q -- "--0x4/0xC--36%" || { echo "Smoke failed: CSI Ctrl+Alt+H did not delete backward block"; exit 1; }
	@bash -lc '{ printf "w"; sleep 0.15; printf "\003"; } | script -q -c "./$(BINARY) /tmp/haxedit-smoke.bin" /tmp/haxedit-viw.log' >/dev/null
	@strings /tmp/haxedit-viw.log | rg -q -- "--0x4/0x10--26%" || { echo "Smoke failed: hex-pane w did not move by block"; exit 1; }
	@bash -lc '{ printf "w"; sleep 0.15; printf "b"; sleep 0.15; printf "\003"; } | script -q -c "./$(BINARY) /tmp/haxedit-smoke.bin" /tmp/haxedit-viwb.log' >/dev/null
	@strings /tmp/haxedit-viwb.log | rg -q -- "--0x0/0x10--0%" || { echo "Smoke failed: hex-pane b did not move backward by block"; exit 1; }
	@cp /tmp/haxedit-smoke.bin /tmp/haxedit-hexy.bin
	@bash -lc '{ printf "y"; sleep 0.15; printf "\030"; } | script -q -c "./$(BINARY) /tmp/haxedit-hexy.bin" /tmp/haxedit-hexy.log' >/dev/null
	@xxd -p -l 1 /tmp/haxedit-hexy.bin | rg -q -- "^00$$" || { echo "Smoke failed: hex-pane 'y' unexpectedly edited first byte"; exit 1; }
	@cp /tmp/haxedit-smoke.bin /tmp/haxedit-ascii.bin
	@bash -lc '{ printf "\t"; sleep 0.15; printf "y"; sleep 0.15; printf "\030"; } | script -q -c "./$(BINARY) /tmp/haxedit-ascii.bin" /tmp/haxedit-ascii.log' >/dev/null
	@xxd -p -l 1 /tmp/haxedit-ascii.bin | rg -q -- "^79$$" || { echo "Smoke failed: ASCII pane 'y' did not insert byte 0x79"; exit 1; }
	@cp /tmp/haxedit-smoke.bin /tmp/haxedit-ascii-h.bin
	@bash -lc '{ printf "\t"; sleep 0.15; printf "h"; sleep 0.15; printf "\030"; } | script -q -c "./$(BINARY) /tmp/haxedit-ascii-h.bin" /tmp/haxedit-ascii-h.log' >/dev/null
	@xxd -p -l 1 /tmp/haxedit-ascii-h.bin | rg -q -- "^68$$" || { echo "Smoke failed: ASCII pane 'h' did not insert byte 0x68"; exit 1; }
	@cp /tmp/haxedit-smoke.bin /tmp/haxedit-ascii-p.bin
	@bash -lc '{ printf "\t"; sleep 0.15; printf "p"; sleep 0.15; printf "\030"; } | script -q -c "./$(BINARY) /tmp/haxedit-ascii-p.bin" /tmp/haxedit-ascii-p.log' >/dev/null
	@xxd -p -l 1 /tmp/haxedit-ascii-p.bin | rg -q -- "^70$$" || { echo "Smoke failed: ASCII pane 'p' did not insert byte 0x70"; exit 1; }
	@cp /tmp/haxedit-smoke.bin /tmp/haxedit-ascii-u.bin
	@bash -lc '{ printf "\t"; sleep 0.15; printf "u"; sleep 0.15; printf "\030"; } | script -q -c "./$(BINARY) /tmp/haxedit-ascii-u.bin" /tmp/haxedit-ascii-u.log' >/dev/null
	@xxd -p -l 1 /tmp/haxedit-ascii-u.bin | rg -q -- "^75$$" || { echo "Smoke failed: ASCII pane 'u' did not insert byte 0x75"; exit 1; }
	@bash -lc '{ printf "f"; sleep 0.15; printf "U"; sleep 0.15; printf "\030"; } | script -q -c "./$(BINARY) /tmp/haxedit-smoke.bin" /tmp/haxedit-redo.log' >/dev/null
	@xxd -p -l 1 /tmp/haxedit-smoke.bin | rg -q -- "^f0$$" || { echo "Smoke failed: plain 'U' changed redo semantics unexpectedly"; exit 1; }
	@bash -lc '{ sleep 0.15; printf "\003"; } | script -q -c "./$(BINARY) --colour /tmp/haxedit-smoke.bin" /tmp/haxedit-colour.log' >/dev/null
	@grep -aF -q "$$(printf '\033[32m11\033[0m')" /tmp/haxedit-colour.log || { echo "Smoke failed: --colour missing expected control-byte highlight"; exit 1; }
	@dd if=/dev/zero of=/tmp/haxedit-wheel.bin bs=1 count=4096 status=none
	@bash -lc '{ printf "\033[<65;20;5M"; sleep 0.2; printf "\003"; } | script -q -c "./$(BINARY) -l16 /tmp/haxedit-wheel.bin" /tmp/haxedit-wheel.log' >/dev/null
	@strings /tmp/haxedit-wheel.log | rg -q -- "^00000030" || { echo "Smoke failed: mouse wheel did not scroll viewport"; exit 1; }
	@bash -lc '{ printf "\r1\r"; sleep 0.2; printf "\r5\r"; sleep 0.2; printf "\033f"; sleep 0.2; printf "\026"; sleep 0.2; printf "\003"; } | script -q -c "./$(BINARY) -s /tmp/haxedit-sector.bin" /tmp/haxedit-sector.log' >/dev/null
	@strings /tmp/haxedit-sector.log | rg -q -- "goto sector:" || { echo "Smoke failed: goto sector prompt not shown"; exit 1; }
	@strings /tmp/haxedit-sector.log | rg -q -- "--0x200/0x800--25%--sector 1" || { echo "Smoke failed: sector goto 1 did not land on 0x200"; exit 1; }
	@count=$$(strings /tmp/haxedit-sector.log | rg -c -- "--0x200/0x800--25%--sector 1"); [ "$$count" -ge 2 ] || { echo "Smoke failed: invalid sector input did not preserve cursor"; exit 1; }
	@strings /tmp/haxedit-sector.log | rg -q -- "--0x208/0x800--25%--sector 1" || { echo "Smoke failed: Alt+F did not advance by 0x8"; exit 1; }
	@strings /tmp/haxedit-sector.log | rg -q -- "--0x308/0x800--37%--sector 1" || { echo "Smoke failed: Ctrl+V did not advance by 0x100"; exit 1; }
	@echo "Smoke OK"

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

.PHONY: all build test smoke install local-install uninstall local-uninstall clean
