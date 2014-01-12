Maintenance Policy for Ruby on Rails
====================================

Support of the Rails framework is divided into four groups: New features, bug
fixes, security issues, and severe security issues. They are handled as
follows, all versions in x.y.z format

--------------------------------------------------------------------------------

New Features
------------

New features are only added to the master branch and will not be made available
in point releases.

Bug Fixes
---------

Only the latest release series will receive bug fixes. When enough bugs are
fixed and its deemed worthy to release a new gem, this is the branch it happens
from.

**Currently included series:** 4.0.z

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

**Currently included series:** 4.0.z, 3.2.z

Severe Security Issues
----------------------

For severe security issues we will provide new versions as above, and also the
last major release series will receive patches and new versions. The
classification of the security issue is judged by the core team.

**Currently included series:** 4.0.z, 3.2.z

Unsupported Release Series
--------------------------

When a release series is no longer supported, it's your own responsibility to
deal with bugs and security issues. We may provide backports of the fixes and
publish them to git, however there will be no new versions released. If you are
not comfortable maintaining your own versions, you should upgrade to a
supported version.
