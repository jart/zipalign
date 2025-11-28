LDLIBS = -lz
PREFIX = /usr/local

zipalign: zipalign.o
zipalign.o: zipalign.c zip.h

.PHONY: clean
clean:
	rm -f zipalign.o zipalign

.PHONY: install
install: zipalign zipalign.1
	mkdir -p $(PREFIX)/bin
	install zipalign $(PREFIX)/bin/zipalign
	mkdir -p $(PREFIX)/share/man/man1
	install -m 0644 zipalign.1 $(PREFIX)/share/man/man1/zipalign.1
