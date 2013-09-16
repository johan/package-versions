default: build

BIN = node_modules/.bin
SRC = $(shell find src -name "*.coffee" -type f | sort)
LIB = $(SRC:src/%.coffee=lib/%.js)

MOCHA_ARGS = --recursive --compilers coffee:coffee-script-redux/register \
	-r coffee-script-redux/register --reporter spec --colors

MOCHA = $(BIN)/mocha
COFFEE = $(BIN)/coffee --js

.PHONY: all build test tag publish setup

all: build test tag publish

build: .package-versions $(LIB)

lib/%.js: src/%.coffee Makefile
	@mkdir -p "$(@D)"
	(echo '#! /usr/bin/env node' ; $(COFFEE) <"$<") >"$@"

$(BIN)/package-versions: lib/package-versions.js
	cp "$<" "$@"
	chmod +x "$@"

test: build
	$(ENTER)
	@$(MOCHA) $(MOCHA_ARGS) && $(LEAVE) || $(FAIL)

tag:
	git tag v`coffee -e "console.log JSON.parse(require('fs').readFileSync 'package.json').version"`

publish:
	@egrep -q '^registry = http://npmjs.org/$$' $$HOME/.npmrc || \
		(echo 'Error: Make ~/.npmrc point at npmjs.org!' >&2 ; false)
	npm publish . --registry http://npmjs.org

assert-on-clean-master: .package-versions
	@[[ "`git rev-parse --abbrev-ref HEAD`" = "master" ]] || \
		$(call ERROR,"Not on master branch")
	@git diff --exit-code --name-status || \
		$(call ERROR,"Uncommitted changes!")

release-patch: assert-on-clean-master
release-minor: assert-on-clean-master
release-major: assert-on-clean-master
release-patch: BUMP = patch
release-minor: BUMP = minor
release-major: BUMP = major
release-patch: release
release-minor: release
release-major: release

release:
	(export VERSION=`echo 'path = "./package.json"; p = require(path);' \
		'p.version = require("semver").inc(p.version, "'$(BUMP)'");' \
		'require("fs").writeFileSync(path, require("./lib/json")(p));' \
		'console.log(p.version);' \
		| node` ; \
	git commit package.json -m "$$VERSION" && \
	git tag -m "$$VERSION" -a "v$$VERSION" && \
	git push origin "v$$VERSION")

# Bootstrap the app for development, auto-installing node_modules if not present
node_modules/*/package.json:
setup:
	$(ENTER)
	npm install && $(LEAVE) || $(FAIL)

# Auto-upgrade node_modules; runs for any make target that uses node, as soon as
# package.json names a package or version not already installed. To bypass this,
# (if you are testing with some older version), "touch .package-versions" before
# you run "make <something>", so this automated dependency does not kick in.
.package-versions: package.json node_modules/*/package.json $(BIN)/package-versions
#	0 = up to date | 1 = need to update | 2 = abort; failed dependency urls
	$(ENTER)
	@node $(BIN)/package-versions -- --dump > $@ ; case $$? in \
	  0) cat $@ ;; \
	  1) rm $@ \
	   ; echo '*** Running \x1B[32mmake setup\x1B[39m for you ***' \
	   ; make setup ;; \
	  127) rm $@ ; echo '*** Please install node! ***' ; false ;; \
	  *) false ;; \
	esac && \
	$(LEAVE) || $(FAIL)

define ENTER
	@echo '[42m[32m                ' $@ '  [39m[49m'
	@echo '[42m[30m   start of make' $@ '  [39m[49m'
	@echo '[42m[32m                ' $@ '  [39m[49m'
endef

define LEAVE
	(echo '[42m[30m   finished make' $@ '  [39m[49m' ; echo)
endef

define FAIL
	(echo '[41m[30m   FAILURE: make' $@ '  [39m[49m' ; echo ; false)
endef

define ERROR
	(echo '[41m[30m   '$(1)'   [39m[49m' 1>&2; false)
endef
