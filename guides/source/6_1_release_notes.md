**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON https://guides.rubyonrails.org.**

Ruby on Rails 6.1 Release Notes
===============================

Highlights in Rails 6.1:

These release notes cover only the major changes. To learn about various bug
fixes and changes, please refer to the change logs or check out the [list of
commits](https://github.com/rails/rails/commits/master) in the main Rails
repository on GitHub.

--------------------------------------------------------------------------------

Upgrading to Rails 6.1
----------------------

If you're upgrading an existing application, it's a great idea to have good test
coverage before going in. You should also first upgrade to Rails 6.0 in case you
haven't and make sure your application still runs as expected before attempting
an update to Rails 6.1. A list of things to watch out for when upgrading is
available in the
[Upgrading Ruby on Rails](upgrading_ruby_on_rails.html#upgrading-from-rails-6-0-to-rails-6-1)
guide.

Major Features
--------------

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

*   Remove deprecated `ActionDispatch::Http::ParameterFilter`.

*   Remove deprecated `force_ssl` at the controller level.

### Deprecations

*   Deprecate `config.action_dispatch.return_only_media_type_on_content_type`.

### Notable changes

*   Change `ActionDispatch::Response#content_type` to return the full Content-Type header.

Action View
-----------

Please refer to the [Changelog][action-view] for detailed changes.

### Removals

*   Remove deprecated `escape_whitelist` from `ActionView::Template::Handlers::ERB`.

*   Remove deprecated `find_all_anywhere` from `ActionView::Resolver`.

*   Remove deprecated `formats` from `ActionView::Template::HTML`.

*   Remove deprecated `formats` from `ActionView::Template::RawFile`.

*   Remove deprecated `formats` from `ActionView::Template::Text`.

*   Remove deprecated `find_file` from `ActionView::PathSet`.

*   Remove deprecated `rendered_format` from `ActionView::LookupContext`.

*   Remove deprecated `find_file` from `ActionView::ViewPaths`.

*   Require that `ActionView::Base` subclasses implement `#compiled_method_container`.

*   Remove deprecated support to pass an object that is not a `ActionView::LookupContext` as the first argument
    in `ActionView::Base#initialize`.

*   Remove deprecated `format` argument `ActionView::Base#initialize`.

*   Remove deprecated `ActionView::Template#refresh`.

*   Remove deprecated `ActionView::Template#original_encoding`.

*   Remove deprecated `ActionView::Template#variants`.

*   Remove deprecated `ActionView::Template#formats`.

*   Remove deprecated `ActionView::Template#virtual_path=`.

*   Remove deprecated `ActionView::Template#updated_at`.

*   Remove deprecated `updated_at` argument required on `ActionView::Template#initialize`.

*   Make `locals` argument required on `ActionView::Template#initialize`.

*   Remove deprecated `ActionView::Template.finalize_compiled_template_methods`.

*   Remove deprecated `config.action_view.finalize_compiled_template_methods`

*   Remove deprecated support to calling `ActionView::ViewPaths#with_fallback` with a block.

*   Remove deprecated support to passing absolute paths to `render template:`.

*   Remove deprecated support to passing relative paths to `render file:`.

*   Remove support to template handlers that don't accept two arguments.

*   Remove deprecated pattern argument in `ActionView::Template::PathResolver`.

*   Remove deprecated support to call private methods from object in some view helpers.

### Deprecations

### Notable changes

Action Mailer
-------------

Please refer to the [Changelog][action-mailer] for detailed changes.

### Removals

*   Remove deprecated `ActionMailer::Base.receive` in favor of [Action Mailbox](https://github.com/rails/rails/tree/master/actionmailbox).

### Deprecations

### Notable changes

Active Record
-------------

Please refer to the [Changelog][active-record] for detailed changes.

### Removals

*   MySQL: Uniqueness validator now respects default database collation,
    no longer enforce case sensitive comparison by default.

*   Remove deprecated methods from `ActiveRecord::ConnectionAdapters::DatabaseLimits`.

    `column_name_length`
    `table_name_length`
    `columns_per_table`
    `indexes_per_table`
    `columns_per_multicolumn_index`
    `sql_query_length`
    `joins_per_query`

*   Remove deprecated `ActiveRecord::ConnectionAdapters::AbstractAdapter#supports_multi_insert?`.

*   Remove deprecated `ActiveRecord::ConnectionAdapters::AbstractAdapter#supports_foreign_keys_in_create?`.

*   Remove deprecated `ActiveRecord::ConnectionAdapters::PostgreSQLAdapter#supports_ranges?`.

*   Remove deprecated `ActiveRecord::Base#update_attributes` and `ActiveRecord::Base#update_attributes!`.

*   Remove deprecated `migrations_path` argument in
    `ActiveRecord::ConnectionAdapter::SchemaStatements#assume_migrated_upto_version`.

*   Remove deprecated `config.active_record.sqlite3.represent_boolean_as_integer`.

*   Remove deprecated methods from `ActiveRecord::DatabaseConfigurations`.

    `fetch`
    `each`
    `first`
    `values`
    `[]=`

*   Remove deprecated `ActiveRecord::Result#to_hash` method.

*   Remove deprecated support for using unsafe raw SQL in `ActiveRecord::Relation` methods.

### Deprecations

*   Deprecate `ActiveRecord::Base.allow_unsafe_raw_sql`.

### Notable changes

*   `relation.create` does no longer leak scope to class level querying methods
    in initialization block and callbacks.

    Before:

        User.where(name: "John").create do |john|
          User.find_by(name: "David") # => nil
        end

    After:

        User.where(name: "John").create do |john|
          User.find_by(name: "David") # => #<User name: "David", ...>
        end

*   Named scope chain does no longer leak scope to class level querying methods.

        class class User < ActiveRecord::Base
          scope :david, -> { User.where(name: "David") }
        end

    Before:

        User.where(name: "John").david
        # SELECT * FROM users WHERE name = 'John' AND name = 'David'

    After:

        User.where(name: "John").david
        # SELECT * FROM users WHERE name = 'David'

*   `where.not` now generates NAND predicates instead of NOR.

     Before:

         User.where.not(name: "Jon", role: "admin")
         # SELECT * FROM users WHERE name != 'Jon' AND role != 'admin'

     After:

         User.where.not(name: "Jon", role: "admin")
         # SELECT * FROM users WHERE NOT (name == 'Jon' AND role == 'admin')

Active Storage
--------------

Please refer to the [Changelog][active-storage] for detailed changes.

### Removals

*   Remove deprecated support to pass `:combine_options` operations to `ActiveStorage::Transformers::ImageProcessing`.

*   Remove deprecated `ActiveStorage::Transformers::MiniMagickTransformer`.

*   Remove deprecated `config.active_storage.queue`.

*   Remove deprecated `ActiveStorage::Downloading`.

### Deprecations

*   Deprecate `Blob.create_after_upload` in favor of `Blob.create_and_upload`.
    ([Pull Request](https://github.com/rails/rails/pull/34827))

### Notable changes

*   Add `Blob.create_and_upload` to create a new blob and upload the given `io`
    to the service.
    ([Pull Request](https://github.com/rails/rails/pull/34827))

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

*   Remove deprecated fallback to `I18n.default_local` when `config.i18n.fallbacks` is empty.

*   Remove deprecated `LoggerSilence` constant.

*   Remove deprecated `ActiveSupport::LoggerThreadSafeLevel#after_initialize`.

*   Remove deprecated `Module#parent_name`, `Module#parent` and `Module#parents`.

*   Remove deprecated file `active_support/core_ext/module/reachable`.

*   Remove deprecated file `active_support/core_ext/numeric/inquiry`.

*   Remove deprecated file `active_support/core_ext/array/prepend_and_append`.

*   Remove deprecated file `active_support/core_ext/hash/compact`.

### Deprecations

### Notable changes

Active Job
----------

Please refer to the [Changelog][active-job] for detailed changes.

### Removals

### Deprecations

*   Deprecate `config.active_job.return_false_on_aborted_enqueue`.

### Notable changes

*   Return `false` when enqueuing a job is aborted.

Action Text
----------

Please refer to the [Changelog][action-text] for detailed changes.

### Removals

### Deprecations

### Notable changes

*   Add method to confirm rich text content existence by adding `?` after
    name of the rich text attribute.
    ([Pull Request](https://github.com/rails/rails/pull/37951))

*   Add `fill_in_rich_text_area` system test case helper to find a trix
    editor and fill it with given HTML content.
    ([Pull Request](https://github.com/rails/rails/pull/35885))

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

[railties]:       https://github.com/rails/rails/blob/master/railties/CHANGELOG.md
[action-pack]:    https://github.com/rails/rails/blob/master/actionpack/CHANGELOG.md
[action-view]:    https://github.com/rails/rails/blob/master/actionview/CHANGELOG.md
[action-mailer]:  https://github.com/rails/rails/blob/master/actionmailer/CHANGELOG.md
[action-cable]:   https://github.com/rails/rails/blob/master/actioncable/CHANGELOG.md
[active-record]:  https://github.com/rails/rails/blob/master/activerecord/CHANGELOG.md
[active-storage]: https://github.com/rails/rails/blob/master/activestorage/CHANGELOG.md
[active-model]:   https://github.com/rails/rails/blob/master/activemodel/CHANGELOG.md
[active-support]: https://github.com/rails/rails/blob/master/activesupport/CHANGELOG.md
[active-job]:     https://github.com/rails/rails/blob/master/activejob/CHANGELOG.md
[action-text]:    https://github.com/rails/rails/blob/master/actiontext/CHANGELOG.md
[action-mailbox]: https://github.com/rails/rails/blob/master/actionmailbox/CHANGELOG.md
[guides]:         https://github.com/rails/rails/blob/master/guides/CHANGELOG.md
