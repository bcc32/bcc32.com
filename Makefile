# Frontend to dune.

.PHONY: default build install uninstall test serve dist clean

default: build

build:
	jbuilder build

test:
	jbuilder runtest -f

serve: build
	cd _build/install/default/share/bcc32-com/ && python3 -m http.server &
	jbuilder exec -- ./server/main.exe

install:
	jbuilder install

uninstall:
	jbuilder uninstall

clean:
	jbuilder clean
# Optionally, remove all files/folders ignored by git as defined
# in .gitignore (-X).
	git clean -dfXq

dist: build
	filename=bcc32-com-$$(git describe --always --dirty).tar.xz           ;\
	tempdir=$$(mktemp -d)                                                 ;\
	mkdir $$tempdir/bcc32-com                                             ;\
	jbuilder install --prefix=$$tempdir/bcc32-com                         ;\
	tar -caf _build/$$filename --owner=0 --group=0 -C $$tempdir bcc32-com ;\
	rm -rf $$tempdir
