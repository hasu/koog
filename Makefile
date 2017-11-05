PKGNAME := koog
VERSION := latest
DISTSUFFIX := $(and $(VERSION),-$(VERSION))
DISTNAME := $(PKGNAME)$(DISTSUFFIX)
DISTHOME := $(PWD)/dist

default : setup

-include local.mk

# if `make setup` fails, you may need to do `make install` first
install :
	raco pkg install --name $(PKGNAME)

setup :
	raco setup $(PKGNAME)

clean :
	find -name compiled -type d -print0 | xargs -0 --no-run-if-empty rm -r

check-pkg-deps :
	raco setup --check-pkg-deps $(PKGNAME)

.PHONY : web

web :
	-rm -r web
	mkdir -p web/manual
	cp -a LICENSE INSTALL.txt index.html web/
	scribble ++main-xref-in --redirect-main http://docs.racket-lang.org/ --html --dest web/manual --dest-name index.html scribblings/koog.scrbl
	chmod -R a+rX web
	tidy -utf8 -eq web/index.html
