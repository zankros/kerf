PREFIX ?= /usr/local
BINDIR = $(PREFIX)/bin
LIBDIR = $(PREFIX)/share/kerf/lib

.PHONY: install uninstall

install:
	install -d "$(BINDIR)" "$(LIBDIR)/kerf"
	install -m 755 kerf "$(BINDIR)/kerf"
	cp -a lib/kerf/. "$(LIBDIR)/kerf/"

uninstall:
	rm -f "$(BINDIR)/kerf"
	rm -rf "$(LIBDIR)/kerf"