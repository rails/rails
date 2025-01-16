**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Maintenance Policy for Ruby on Rails
====================================

Support of the Rails framework is divided into three groups: New features, bug
fixes, and security issues. They are handled as
follows, all versions, except for security releases, in `X.Y.Z`, format.

--------------------------------------------------------------------------------

Versioning
------------

Rails follows a shifted version of [semver](https://semver.org/):

**Patch `Z`**

Only bug fixes, no API changes, no new features.
Except as necessary for security fixes.

**Minor `Y`**

New features, may contain API changes (Serve as major versions of Semver).
Breaking changes are paired with deprecation notices in the previous minor
or major release.

**Major `X`**

New features, will likely contain API changes. The difference between Rails'
minor and major releases is the magnitude of breaking changes, and usually
reserved for special occasions.

New Features
------------

New features are only added to the main branch and will not be made available
in Patch releases.

Bug Fixes
---------

Minor releases will receive bug fixes for one year after the first release in
its series. For example, if a theoretical 1.1.0 is released on January 1, 2023, it
will receive bug fixes until January 1, 2024. After that, it will be considered
unsupported.

Bug fixes are typically added to the main branch, and backported to the x-y-stable
branch of the latest release series if there is sufficient need. When enough bugs
fixes have been added to an x-y-stable branch, a new Patch release is built from it.
For example, a theoretical 1.2.2 Patch release would be built from the 1-2-stable branch.

For unsupported series, bug fixes may coincidentally land in a stable branch,
but won't be released in an official version. It is recommended to point your
application at the stable branch using Git for unsupported versions.

Security Issues
---------------

Minor releases will receive security fixes for two years after the first release in
its series. For example, if a theoretical 1.1.0 is released on January 1, 2023, it
will receive security fixes until January 1, 2025. After that, it will reach its
end-of-life.

These releases are created by taking the last released version, applying the
security patches, and releasing. Those patches are then applied to the end of
the x-y-stable branch. For example, a theoretical 1.2.2.1 security release would
be built from 1.2.2, and then added to the end of 1-2-stable. This means that
security releases are easy to upgrade to if you're running the latest version
of Rails.

Only direct security patches will be included in security releases. Fixes for
non-security related bugs resulting from a security patch may be published on a
release's x-y-stable branch, and will only be released as a new gem in
accordance with the Bug Fixes policy.

Security releases are cut from the last security release branch/tag. Otherwise
there could be breaking changes in the security release. A security release
should only contain the changes needed to ensure the app is secure so that it's
easier for applications to remain upgraded.

End-of-life Release Series
--------------------------

When a release series reaches its end-of-life, it's your own responsibility to
deal with bugs and security issues. We may provide backports of the fixes and
merge them, however there will be no new versions released. We
recommend to point your application at the stable branch using Git. If you are
not comfortable maintaining your own versions, you should upgrade to a supported
version.

Release schedule
----------------

We aim to release a version containing new features every six months. In the rare case where
no release was made in one year, we will extend the support period for the previous release
until the next release is made.

npm Packages
------------

Due to a constraint with npm, we are unable to use the 4th digit for security
releases of [npm packages][] provided by Rails. This means that instead of the
equivalent gem version `7.0.1.4`, the npm package will be versioned `7.0.104`.

The version will be calculated as `X.Y.Z0A`, where `A` is the security release.

[npm packages]: https://www.npmjs.com/org/rails
