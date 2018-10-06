**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON https://guides.rubyonrails.org.**

Ruby on Rails 6.0 Release Notes
===============================

Highlights in Rails 6.0:

* Parallel Testing

These release notes cover only the major changes. To learn about various bug
fixes and changes, please refer to the change logs or check out the [list of
commits](https://github.com/rails/rails/commits/6-0-stable) in the main Rails
repository on GitHub.

--------------------------------------------------------------------------------

Upgrading to Rails 6.0
----------------------

If you're upgrading an existing application, it's a great idea to have good test
coverage before going in. You should also first upgrade to Rails 5.2 in case you
haven't and make sure your application still runs as expected before attempting
an update to Rails 6.0. A list of things to watch out for when upgrading is
available in the
[Upgrading Ruby on Rails](upgrading_ruby_on_rails.html#upgrading-from-rails-5-2-to-rails-6-0)
guide.

Major Features
--------------

### Parallel Testing

[Pull Request](https://github.com/rails/rails/pull/31900)

[Parallel Testing](testing.html#parallel-testing) allows you to parallelize your
test suite. While forking processes is the default method, threading is
supported as well. Running tests in parallel reduces the time it takes
your entire test suite to run.

Railties
--------

Please refer to the [Changelog][railties] for detailed changes.

### Removals

### Deprecations

### Notable changes

Action Cable
------------

Please refer to the [Changelog][action-cable] for detailed changes.

### Removals

### Deprecations

### Notable changes

Action Pack
-----------

Please refer to the [Changelog][action-pack] for detailed changes.

### Removals

### Deprecations

### Notable changes

Action View
-----------

Please refer to the [Changelog][action-view] for detailed changes.

### Removals

### Deprecations

### Notable changes

Action Mailer
-------------

Please refer to the [Changelog][action-mailer] for detailed changes.

### Removals

### Deprecations

### Notable changes

Active Record
-------------

Please refer to the [Changelog][active-record] for detailed changes.

### Removals

### Deprecations

### Notable changes

Active Storage
--------------

Please refer to the [Changelog][active-storage] for detailed changes.

### Removals

### Deprecations

### Notable changes

Active Model
------------

Please refer to the [Changelog][active-model] for detailed changes.

### Removals

### Deprecations

### Notable changes

Active Support
--------------

Please refer to the [Changelog][active-support] for detailed changes.

### Removals

### Deprecations

### Notable changes

Active Job
----------

Please refer to the [Changelog][active-job] for detailed changes.

### Removals

### Deprecations

### Notable changes

Ruby on Rails Guides
--------------------

Please refer to the [Changelog][guides] for detailed changes.

### Notable changes

Credits
-------

See the
[full list of contributors to Rails](http://contributors.rubyonrails.org/)
for the many people who spent many hours making Rails, the stable and robust
framework it is. Kudos to all of them.

[railties]:       https://github.com/rails/rails/blob/6-0-stable/railties/CHANGELOG.md
[action-pack]:    https://github.com/rails/rails/blob/6-0-stable/actionpack/CHANGELOG.md
[action-view]:    https://github.com/rails/rails/blob/6-0-stable/actionview/CHANGELOG.md
[action-mailer]:  https://github.com/rails/rails/blob/6-0-stable/actionmailer/CHANGELOG.md
[action-cable]:   https://github.com/rails/rails/blob/6-0-stable/actioncable/CHANGELOG.md
[active-record]:  https://github.com/rails/rails/blob/6-0-stable/activerecord/CHANGELOG.md
[active-storage]: https://github.com/rails/rails/blob/6-0-stable/activestorage/CHANGELOG.md
[active-model]:   https://github.com/rails/rails/blob/6-0-stable/activemodel/CHANGELOG.md
[active-support]: https://github.com/rails/rails/blob/6-0-stable/activesupport/CHANGELOG.md
[active-job]:     https://github.com/rails/rails/blob/6-0-stable/activejob/CHANGELOG.md
[guides]:         https://github.com/rails/rails/blob/6-0-stable/guides/CHANGELOG.md
