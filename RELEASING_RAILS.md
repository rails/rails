# Releasing Rails

In this document, we'll cover the steps necessary to release Rails. Each
section contains steps to take during that time before the release. The times
suggested in each header are just that: suggestions. However, they should
really be considered as minimums.

## 10 Days before release

Today is mostly coordination tasks. Here are the things you must do today:

### Is the CI green? If not, make it green. (See "Fixing the CI")

Do not release with a Red CI. You can find the CI status here:

```
https://buildkite.com/rails/rails
```

### Do we have any Git dependencies? If so, contact those authors.

Having Git dependencies indicates that we depend on unreleased code.
Obviously Rails cannot be released when it depends on unreleased code.
Contact the authors of those particular gems and work out a release date that
suits them.

### Announce your plans to the rest of the team on Campfire

Let them know of your plans to release.

### Update each CHANGELOG.

Many times commits are made without the CHANGELOG being updated. You should
review the commits since the last release, and fill in any missing information
for each CHANGELOG.

You can review the commits for the 3.0.10 release like this:

```
[aaron@higgins rails (3-0-10)]$ git log v3.0.9..
```

If you're doing a stable branch release, you should also ensure that all of
the CHANGELOG entries in the stable branch are also synced to the main
branch.

## Day of release

If making multiple releases. Publish them in order from oldest to newest, to
ensure that the "greatest" version also shows up in NPM and GitHub Releases as
"latest".

### Put the new version in the RAILS_VERSION file.

Include an RC number if appropriate, e.g. `6.0.0.rc1`.

### Build and test the gem.

Run `rake verify` to generate the gems and install them locally. `verify` also
generates a Rails app with a migration and boots it to smoke test with in your
browser.

This will stop you from looking silly when you push an RC to rubygems.org and
then realize it is broken.

### Check credentials for RubyGems, npm, and GitHub

For npm run `npm whoami` to check that you are logged in (`npm login` if not).

For RubyGems run `gem login`. If there's no output you are logged in.

For GitHub run `gh auth status` to check that you are logged in (run `gh login` if not).

npm and RubyGems require MFA. The release task will attempt to use a yubikey if
available, which as we have release several packages at once is strongly
recommended. Check that `ykman oath accounts list` has an entry for both
`npmjs.com` and `rubygems.org`, if not refer to
https://tenderlovemaking.com/2021/10/26/publishing-gems-with-your-yubikey.html
for setup instructions.

### Release to RubyGems and npm.

IMPORTANT: Several gems have JavaScript components that are released as npm
packages, so you must have Node.js installed, have an npm account (npmjs.com),
and be a package owner for `@rails/actioncable`, `@rails/actiontext`,
`@rails/activestorage`, and `@rails/ujs`. You can check this by making sure your
npm user (`npm whoami`) is listed as an owner (`npm owner ls <pkg>`) of each
package. Do not release until you're set up with npm!

The release task will sign the release tag. If you haven't got commit signing
set up, use https://git-scm.com/book/en/v2/Git-Tools-Signing-Your-Work as a
guide. You can generate keys with the GPG suite from here: https://gpgtools.org.

Run `rake changelog:header` to put a header with the new version in every
CHANGELOG. Don't commit this, the release task handles it.

Run `rake release`. This will populate the gemspecs and npm package.json with
the current RAILS_VERSION, commit the changes, tag it, and push the gems to
rubygems.org.

### Make GitHub Releases from pushed tags

We use GitHub Releases to publish the combined release summary for all gems. We
can use a rake task and [GitHub cli](https://cli.github.com/) to do this
(releases can also be created or edited on the web).

```
bundle exec rake changelog:release_summary > ../6-1-7-release-summary.md
gh release create v6.1.7 -R rails/rails -F ../6-1-7-release-summary.md
```

### Send Rails release announcements

Write a release announcement that includes the version, changes, and links to
GitHub where people can find the specific commit list. Here are the mailing
lists where you should announce:

* [rubyonrails-core](https://discuss.rubyonrails.org/c/rubyonrails-core)
* [rubyonrails-talk](https://discuss.rubyonrails.org/c/rubyonrails-talk)
* ruby-talk@ruby-lang.org

Use Markdown format for your announcement. Remember to ask people to report
issues with the release candidate to the rails-core mailing list.

NOTE: For patch releases, there's a `rake announce` task to generate the release
post. It supports multiple patch releases too:

```
VERSIONS="5.0.5.rc1,5.1.3.rc1" rake announce
```

IMPORTANT: If any users experience regressions when using the release
candidate, you *must* postpone the release. Bugfix releases *should not*
break existing applications.

### Post the announcement to the Rails blog.

The blog at https://rubyonrails.org/blog is built from
https://github.com/rails/website.

Create a file named like
`_posts/$(date +'%F')-Rails-<versions>-have-been-released.markdown`

Add YAML frontmatter
```
---
layout: post
title: 'Rails <VERSIONS> have been released!'
categories: releases
author: <your handle>
published: true
date: <YYYY-MM-DD or `date +%F`>
---
```

Use the markdown generated by `rake announce` earlier as a base for the post.
Add some context for users as to the purpose of this release (bugfix/security).

If this is a part of the latest release series, update `_data/version.yml` so
that the homepage points to the latest version.

### Post the announcement to the Rails Twitter account.

## Security releases

### Emailing the Rails security announce list

Email the security announce list once for each vulnerability fixed.

You can do this, or ask the security team to do it.

Email the security reports to:

* rubyonrails-security@googlegroups.com
* oss-security@lists.openwall.com

Be sure to note the security fixes in your announcement along with CVE numbers
and links to each patch. Some people may not be able to upgrade right away,
so we need to give them the security fixes in patch form.

* Blog announcements
* Twitter announcements
* Merge the release branch to the stable branch
* Drink beer (or other cocktail)

## Misc

### Fixing the CI

There are two simple steps for fixing the CI:

1. Identify the problem
2. Fix it

Repeat these steps until the CI is green.
