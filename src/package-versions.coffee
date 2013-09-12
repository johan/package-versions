#! /usr/bin/env coffee

# Reads out all the versions of package.json dependencies, then all node_modules
# package.jsons and exit(0)s if all dependencies were met, 1 if some were not or
# 2 if there were git urls that didn't reference a semver #v<refspec> tag/branch

# passing --dump will write your installed package names and versions to stdout.

fs = require 'fs'
pkg = JSON.parse fs.readFileSync 'package.json', 'utf8'
glob = require 'glob'
async = require 'async'
semver = require 'semver'

# Load and parse all package.json files listed in packagePaths. Pass an object
# from package name to version to the callback once done. (Ignores any errors;
# your node_modules may have as much random junk in them as you like, given it
# also has correct packages for the ones your package.json depends upon.)
getPackageVersions = (packagePaths, cb) ->
  unread = packagePaths.length
  version = {}
  packagePaths.forEach (path) ->
    fs.readFile path, 'utf8', (err, raw) ->
      try
        current = JSON.parse raw
        version[current.name] = current.version
      catch e
        console.warn "Error parsing #{path}: #{e.stack}" # not a terminal error!
      if --unread is 0
        cb null, version

# Asserts that packace `name` matches `versionSpec`, given `installedVersions`.
# Updates `usedVersions` with `name: installedVersion[name]` (when satisfied).
assertVersionMatch = (installedVersion, usedVersions, name, versionSpec) ->
  unless semver.validRange versionSpec
    tagOrBranchName = versionSpec.replace /^.*\#v/, '' # drop git://github/...
    if semver.validRange tagOrBranchName
      versionSpec = tagOrBranchName
    else
      help = """Missing \"#{name}\" version in \"#{versionSpec}\"
        Please name and push your git tags/branches \"v<package.json version>\".

        This way, starting your server and ensuring your npm modules are up to
        date happens in ~10ms, with no network roundtrips -- instead of adding
        multi-second delays for every git url dependency in package.json"""
      error = new Error help
      error.fatal = true
      throw error

  version = installedVersion[name]
  throw new Error "#{name} is not installed"  unless version?
  if semver.satisfies version, versionSpec
    usedVersions[name] = version
  else
    throw new Error "#{name} version #{version} doesn't satisfy #{versionSpec}"

# comma-first formatting of a JSON object for maximum diff friendliness
format = do ->
  tailOp = /\ ?([\[\{,])\n ( *)(?: )/gm # trailing->leading ,-{-[s
  leadOp = '\n$2$1 '
  cuddle = /(^|[\[\{,] ?)\n */gm # cuddle brackets/braces/array items
  (json) ->
    JSON.stringify(json, null, 2).replace(tailOp, leadOp).replace(cuddle, '$1')

getPackageVersions glob.sync('node_modules/*/package.json'), (e, allVersions) ->
  used = {} # used package versions in the same order as in package.json
  exitCode = 0

  try
    assertFreshness = assertVersionMatch.bind this, allVersions, used
    assertFreshness name, ver  for name, ver of pkg.dependencies ? {}
    assertFreshness name, ver  for name, ver of pkg.devDependencies ? {}
    console.log format used  if process.argv.indexOf('--dump') >= 0
  catch error
    console.error error.message
    exitCode = 1
    exitCode = 2 if error.fatal

  process.exit exitCode
