# Frontend to dune.

.PHONY: default build install uninstall test serve clean

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
