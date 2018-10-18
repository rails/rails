**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON https://guides.rubyonrails.org.**

Maintenance Policy for Ruby on Rails
====================================

Support of the Rails framework is divided into four groups: New features, bug
fixes, security issues, and severe security issues. They are handled as
follows, all versions in `X.Y.Z` format.

--------------------------------------------------------------------------------

Rails follows a shifted version of [semver](http://semver.org/):

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

New features are only added to the master branch and will not be made available
in point releases.

Bug Fixes
---------

Only the latest release series will receive bug fixes. When enough bugs are
fixed and its deemed worthy to release a new gem, this is the branch it happens
from.

In special situations, where someone from the Core Team agrees to support more series,
they are included in the list of supported series.

**Currently included series:** `5.2.Z`.

Security Issues
---------------

The current release series and the next most recent one will receive patches
and new versions in case of a security issue.

These releases are created by taking the last released version, applying the
security patches, and releasing. Those patches are then applied to the end of
the x-y-stable branch. For example, a theoretical 1.2.3 security release would
be built from 1.2.2, and then added to the end of 1-2-stable. This means that
security releases are easy to upgrade to if you're running the latest version
of Rails.

**Currently included series:** `5.2.Z`, `5.1.Z`.

Severe Security Issues
----------------------

For severe security issues all releases in the current major series, and also the
last major release series will receive patches and new versions. The
classification of the security issue is judged by the core team.

**Currently included series:** `5.2.Z`, `5.1.Z`, `5.0.Z`, `4.2.Z`.

Unsupported Release Series
--------------------------

When a release series is no longer supported, it's your own responsibility to
deal with bugs and security issues. We may provide backports of the fixes and
publish them to git, however there will be no new versions released. If you are
not comfortable maintaining your own versions, you should upgrade to a
supported version.
