**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Ruby on Rails 8.2 Release Notes
===============================

Highlights in Rails 8.2:

These release notes cover only the major changes. To learn about various bug
fixes and changes, please refer to the changelogs or check out the [list of
commits](https://github.com/rails/rails/commits/main) in the main Rails
repository on GitHub.

--------------------------------------------------------------------------------

Upgrading to Rails 8.2
----------------------

If you're upgrading an existing application, it's a great idea to have good test
coverage before going in. You should also first upgrade to Rails 8.1 in case you
haven't and make sure your application still runs as expected before attempting
an update to Rails 8.1. A list of things to watch out for when upgrading is
available in the
[Upgrading Ruby on Rails](upgrading_ruby_on_rails.html#upgrading-from-rails-8-1-to-rails-8-2)
guide.

Major Features
--------------

Railties
--------

Please refer to the [Changelog][railties] for detailed changes.

### Removals

### Deprecations

### Notable changes

*   Add `Rails.app` as an alias for `Rails.application`.

*   Add `Rails.app.revision` to provide a version identifier for error reporting,
    monitoring, and cache keys. By default it reads from a `REVISION` file or the
    local git SHA.

*   Add `Rails.app.creds` for combined access to credentials stored in either ENV
    or the encrypted credentials file, with `require` and `option` methods.

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

*   Deprecate calling `protect_from_forgery` without specifying a strategy.

    The current default of `:null_session` is inconsistent with
    `config.action_controller.default_protect_from_forgery`, which uses `:exception`.
    Explicitly pass `with: :null_session` to silence the warning, or set
    `config.action_controller.default_protect_from_forgery_with = :exception` to opt
    into the new behavior.

*   Deprecate `InvalidAuthenticityToken` in favor of `InvalidCrossOriginRequest`,
    as part of the new header-based CSRF protection.

### Notable changes

*   Add modern header-based CSRF protection using the `Sec-Fetch-Site` header to
    verify same-origin requests without requiring authenticity tokens. Two strategies
    are available via `protect_from_forgery using:`: `:header_only` (default for new
    8.2 apps) and `:header_or_legacy_token` (falls back to token verification for
    older browsers).

Action View
-----------

Please refer to the [Changelog][action-view] for detailed changes.

### Removals

### Deprecations

### Notable changes

*   Add ability to pass a block when rendering a collection. The block is executed
    for each rendered element in the collection.

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

*   PostgreSQL `DROP DATABASE` now automatically uses the `FORCE` option on
    supported versions, disconnecting clients before dropping. This allows
    `bin/rails db:reset` and similar commands to work without first shutting
    down running app instances or consoles.

*   Fix SQLite3 data loss during table alterations when child tables have
    `ON DELETE CASCADE` foreign keys. Schema changes no longer silently
    trigger CASCADE deletes on child tables.

*   Add `implicit_persistence_transaction` hook for customizing transaction
    behavior. This protected method wraps `save`, `destroy`, and `touch` in a
    transaction and can be overridden in models to set a specific isolation level
    or skip transaction creation when one is already open.

Active Storage
--------------

Please refer to the [Changelog][active-storage] for detailed changes.

### Removals

### Deprecations

*   Deprecate `preprocessed: true` variant option in favor of `process: :later`.

### Notable changes

*   Analyze attachments before validation. Attachment metadata (width, height,
    duration, etc.) is now available for model validations. Configure timing with
    `analyze: :immediately` (default), `:later`, or `:lazily`.

*   Add immediate variant processing via the `process: :immediately` option, which
    generates variants during attachment instead of lazily or in a background job.

Active Model
------------

Please refer to the [Changelog][active-model] for detailed changes.

### Removals

### Deprecations

### Notable changes

*   Add `has_json` and `has_delegated_json` to provide schema-enforced access to
    JSON attributes with type casting and default values.

*   Add built-in Argon2 support for `has_secure_password` via `algorithm: :argon2`.
    Argon2 has no password length limit, unlike BCrypt's 72-byte restriction. A new
    `ActiveModel::SecurePassword.register_algorithm` API allows registering custom
    password hashing algorithms.

Active Support
--------------

Please refer to the [Changelog][active-support] for detailed changes.

### Removals

### Deprecations

### Notable changes

*   Add `SecureRandom.base32` for generating case-insensitive keys that are
    unambiguous to humans.

*   Parallel tests are now deterministically assigned to workers in round-robin
    order, making flaky test failures caused by test interdependence easier to
    reproduce. Enable `work_stealing: true` to allow idle workers to steal tests
    from busy workers for faster runtime.

Active Job
----------

Please refer to the [Changelog][active-job] for detailed changes.

### Removals

*   Remove deprecated `sidekiq` Active Job adapter.

    The adapter is available in the `sidekiq` gem.

### Deprecations

*   Deprecate built-in `queue_classic`, `resque`, `delayed_job`, `backburner`, and
    `sneakers` Active Job adapters. If using `resque` (3.0+) or `delayed_job` (4.2.0+),
    upgrade to use the gem's own adapter.

### Notable changes

*   Un-deprecate `config.active_job.enqueue_after_transaction_commit` and default
    it to `true` for new applications. This setting was deprecated in 8.0 and
    non-functional in 8.1; it now works as a boolean config. Jobs are now enqueued
    after transaction commit by default, fixing jobs that would previously run
    against uncommitted or rolled-back records.

Action Text
----------

Please refer to the [Changelog][action-text] for detailed changes.

### Removals

### Deprecations

*   Deprecate Trix-specific classes, modules, and methods:
    `ActionText::TrixAttachment`, `ActionText::Attachments::TrixConversion`,
    `ActionText::Content#to_trix_html`, `ActionText::RichText#to_trix_html`, and
    `ActionText::Attachable#to_trix_content_attachment_partial_path` (use
    `#to_editor_content_attachment_partial_path` instead).

### Notable changes

Action Mailbox
----------

Please refer to the [Changelog][action-mailbox] for detailed changes.

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
[full list of contributors to Rails](https://contributors.rubyonrails.org/)
for the many people who spent many hours making Rails, the stable and robust
framework it is. Kudos to all of them.

[railties]:       https://github.com/rails/rails/blob/main/railties/CHANGELOG.md
[action-pack]:    https://github.com/rails/rails/blob/main/actionpack/CHANGELOG.md
[action-view]:    https://github.com/rails/rails/blob/main/actionview/CHANGELOG.md
[action-mailer]:  https://github.com/rails/rails/blob/main/actionmailer/CHANGELOG.md
[action-cable]:   https://github.com/rails/rails/blob/main/actioncable/CHANGELOG.md
[active-record]:  https://github.com/rails/rails/blob/main/activerecord/CHANGELOG.md
[active-storage]: https://github.com/rails/rails/blob/main/activestorage/CHANGELOG.md
[active-model]:   https://github.com/rails/rails/blob/main/activemodel/CHANGELOG.md
[active-support]: https://github.com/rails/rails/blob/main/activesupport/CHANGELOG.md
[active-job]:     https://github.com/rails/rails/blob/main/activejob/CHANGELOG.md
[action-text]:    https://github.com/rails/rails/blob/main/actiontext/CHANGELOG.md
[action-mailbox]: https://github.com/rails/rails/blob/main/actionmailbox/CHANGELOG.md
[guides]:         https://github.com/rails/rails/blob/main/guides/CHANGELOG.md
