package-versions
----------------

You have better things to do
than figuring out when to run
`npm install` in your node app.

Whether it's a first install,
or someone just pushed
a new or changed dependency
to `package.json` underfoot.

Here – use this `Makefile` stub:

```
# add a `.package-versions` dependency to all node targets
dev: .package-versions
	npm start # or however you invoke your app

# Bootstrap the app for development, auto-installing node_modules if not present
node_modules/*/package.json:
setup:
	@npm install

# Auto-upgrade node_modules; runs for any make target that uses node, as soon as
# package.json names a package or version not already installed. To bypass this,
# (if you are testing with some older version), "touch .package-versions" before
# you run "make <something>", so this automated dependency does not kick in.
.package-versions: package.json node_modules/*/package.json
#	0 = up to date | 1 = need to update | 2 = abort; failed dependency urls
	@echo 'installed package versions:'
	@node $(BIN)/package-versions -- --dump > $@ ; case $$? in \
	  0) cat $@ ;; \
	  1) rm $@ \
	   ; echo '*** Running \x1B[32mmake setup\x1B[39m for you ***' \
	   ; make setup ;; \
          127) rm $@ ; echo '*** Please install node! ***' ; false ;; \
	  *) false ;; \
	esac
```
