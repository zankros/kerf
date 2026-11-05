PREFIX ?= /usr/local
BINDIR = $(PREFIX)/bin
LIBDIR = $(PREFIX)/share/kerf

.PHONY: install uninstall

install:
	install -d "$(BINDIR)" "$(LIBDIR)"
	install -m 755 kerf "$(BINDIR)/kerf"
	cp -a *.scm "$(LIBDIR)/"

uninstall:
	rm -f "$(BINDIR)/kerf"
	rm -rf "$(LIBDIR)"