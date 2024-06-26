# GHC major.minor
GHC_VERSION := $(shell ghc --numeric-version | cut -d. -f1-2)
BNFC_VERSION=$(shell sed -ne "s/^[Vv]ersion: *\([0-9.]*\).*/\1/p" BNFC.cabal)

# Cabal options (to be overwritten from the command line)
CABAL_OPTS           =
CABAL_BUILDDIR_SUFFIX=
CABAL_BUILD_OPTS     = --enable-tests
# --builddir=dist-ghc-$(GHC_VERSION)$(CABAL_BUILDDIR_SUFFIX)
CABAL_CONFIGURE_OPTS = --enable-tests
CABAL_INSTALL_OPTS   = --overwrite-policy=always
CABAL_TEST_OPTS      = $(CABAL_BUILD_OPTS)

CABAL                = cabal $(CABAL_OPTS)
CABAL_CONFIGURE      = $(CABAL) configure $(CABAL_CONFIGURE_OPTS)
CABAL_BUILD          = $(CABAL) build     $(CABAL_BUILD_OPTS)
CABAL_INSTALL        = $(CABAL) install   $(CABAL_INSTALL_OPTS)
CABAL_TEST           = $(CABAL) test      $(CABAL_TEST_OPTS)

# Name for binary distribution (e.g. bnfc-2.4.5-linux32)
BDIST_TAG=bnfc-${BNFC_VERSION}-$(shell uname -s)-$(shell uname -m)

.PHONY: default build install doc test bdist show-version debug weed TAGS

default: build cabal-test doctest-quick

build:
	$(CABAL_BUILD)

install:
	$(CABAL_INSTALL)

test: build cabal-test doctest

cabal-test:
	$(CABAL_TEST)

doctest: build doctest-install doctest-quick

doctest-install:
	cabal install doctest --ignore-project --program-suffix=-${GHC_VERSION}

doctest-quick:
	cabal repl -w doctest-${GHC_VERSION} --repl-options=-Wno-type-defaults
# --ghc-options=-Wno-type-defaults needed due to OverloadedStrings.
# But it does not get used here, needs to go into cabal file.
# see: https://github.com/sol/doctest/issues/390
# --repl-options seems to work, though

haddock:
	$(CABAL) haddock

# See https://hackage.haskell.org/package/weeder
# weeder can find dead code starting from the .hie files
weed:
	$(CABAL) build --project-file=cabal.project.local
	weeder

TAGS :
	hasktags --etags .

# Binary package (tgz, for linux)
bdist: dist/${BDIST_TAG}.tar.gz

# Source package
# Andreas, 2023-11-03, PR #466: need to remove BNFC/{Lex,Par}.hs,
# otherwise they will be shipped in the sdist package
# and cause compilation to fail.
sdist:
	make -C src clean
	cabal sdist

# OLD goal
dist/%.tar.gz:
	cabal v1-clean
	cabal v1-install ${CABAL_OPTS} --only-dependencies
	cabal v1-configure ${CABAL_OPTS} --prefix=/
	cabal v1-build ${CABAL_OPTS}
	cabal v1-copy --destdir=dist/install
	mkdir dist/$*
	cp dist/install/bin/bnfc dist/$*
	cp LICENSE dist/$*
	tar -cvz -C dist $* > $@

# Print the bnfc version from the cabal file
show-version:
	@echo ${BNFC_VERSION}

debug:
	@echo GHC_VERSION  = $(GHC_VERSION)
	@echo BNFC_VERSION = $(BNFC_VERSION)
# EOF
