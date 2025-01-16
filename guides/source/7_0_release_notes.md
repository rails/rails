**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Ruby on Rails 7.0 Release Notes
===============================

Highlights in Rails 7.0:

* Ruby 2.7.0+ required, Ruby 3.0+ preferred

--------------------------------------------------------------------------------

Upgrading to Rails 7.0
----------------------

If you're upgrading an existing application, it's a great idea to have good test
coverage before going in. You should also first upgrade to Rails 6.1 in case you
haven't and make sure your application still runs as expected before attempting
an update to Rails 7.0. A list of things to watch out for when upgrading is
available in the
[Upgrading Ruby on Rails](upgrading_ruby_on_rails.html#upgrading-from-rails-6-1-to-rails-7-0)
guide.

Major Features
--------------

Railties
--------

Please refer to the [Changelog][railties] for detailed changes.

### Removals

*   Remove deprecated `config` in `dbconsole`.

### Deprecations

### Notable changes

*   Sprockets is now an optional dependency

    The gem `rails` doesn't depend on `sprockets-rails` anymore. If your application still needs to use Sprockets,
    make sure to add `sprockets-rails` to your Gemfile.

    ```
    gem "sprockets-rails"
    ```

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

*   Remove deprecated `ActionDispatch::Response.return_only_media_type_on_content_type`.

*   Remove deprecated `Rails.config.action_dispatch.hosts_response_app`.

*   Remove deprecated `ActionDispatch::SystemTestCase#host!`.

*   Remove deprecated support to passing a path to `fixture_file_upload` relative to `fixture_path`.

### Deprecations

### Notable changes

Action View
-----------

Please refer to the [Changelog][action-view] for detailed changes.

### Removals

*   Remove deprecated `Rails.config.action_view.raise_on_missing_translations`.

### Deprecations

### Notable changes

*  `button_to` infers HTTP verb [method] from an Active Record object if object is used to build URL

    ```ruby
    button_to("Do a POST", [:do_post_action, Workshop.find(1)])
    # Before
    #=>   <input type="hidden" name="_method" value="post" autocomplete="off" />
    # After
    #=>   <input type="hidden" name="_method" value="patch" autocomplete="off" />
    ```

Action Mailer
-------------

Please refer to the [Changelog][action-mailer] for detailed changes.

### Removals

*   Remove deprecated `ActionMailer::DeliveryJob` and `ActionMailer::Parameterized::DeliveryJob`
    in favor of `ActionMailer::MailDeliveryJob`.

### Deprecations

### Notable changes

Active Record
-------------

Please refer to the [Changelog][active-record] for detailed changes.

### Removals

*   Remove deprecated `database` kwarg from `connected_to`.

*   Remove deprecated  `ActiveRecord::Base.allow_unsafe_raw_sql`.

*   Remove deprecated option `:spec_name` in the `configs_for` method.

*   Remove deprecated support to YAML load `ActiveRecord::Base` instance in the Rails 4.2 and 4.1 formats.

*   Remove deprecation warning when `:interval` column is used in PostgreSQL database.

    Now, interval columns will return `ActiveSupport::Duration` objects instead of strings.

    To keep the old behavior, you can add this line to your model:

    ```ruby
    attribute :column, :string
    ```

*   Remove deprecated support to resolve connection using `"primary"` as connection specification name.

*   Remove deprecated support to quote `ActiveRecord::Base` objects.

*   Remove deprecated support to type cast to database values `ActiveRecord::Base` objects.

*   Remove deprecated support to pass a column to `type_cast`.

*   Remove deprecated `DatabaseConfig#config` method.

*   Remove deprecated rake tasks:

    * `db:schema:load_if_ruby`
    * `db:structure:dump`
    * `db:structure:load`
    * `db:structure:load_if_sql`
    * `db:structure:dump:#{name}`
    * `db:structure:load:#{name}`
    * `db:test:load_structure`
    * `db:test:load_structure:#{name}`

*   Remove deprecated support to `Model.reorder(nil).first` to search using non-deterministic order.

*   Remove deprecated `environment` and `name` arguments from `Tasks::DatabaseTasks.schema_up_to_date?`.

*   Remove deprecated `Tasks::DatabaseTasks.dump_filename`.

*   Remove deprecated `Tasks::DatabaseTasks.schema_file`.

*   Remove deprecated `Tasks::DatabaseTasks.spec`.

*   Remove deprecated `Tasks::DatabaseTasks.current_config`.

*   Remove deprecated `ActiveRecord::Connection#allowed_index_name_length`.

*   Remove deprecated `ActiveRecord::Connection#in_clause_length`.

*   Remove deprecated `ActiveRecord::DatabaseConfigurations::DatabaseConfig#spec_name`.

*   Remove deprecated `ActiveRecord::Base.connection_config`.

*   Remove deprecated `ActiveRecord::Base.arel_attribute`.

*   Remove deprecated `ActiveRecord::Base.configurations.default_hash`.

*   Remove deprecated `ActiveRecord::Base.configurations.to_h`.

*   Remove deprecated `ActiveRecord::Result#map!` and `ActiveRecord::Result#collect!`.

*   Remove deprecated `ActiveRecord::Base#remove_connection`.

### Deprecations

*   Deprecated `Tasks::DatabaseTasks.schema_file_type`.

### Notable changes

*   Rollback transactions when the block returns earlier than expected.

    Before this change, when a transaction block returned early, the transaction would be committed.

    The problem is that timeouts triggered inside the transaction block was also making the incomplete transaction
    to be committed, so in order to avoid this mistake, the transaction block is rolled back.

*   Merging conditions on the same column no longer maintain both conditions,
    and will be consistently replaced by the latter condition.

    ```ruby
    # Rails 6.1 (IN clause is replaced by merger side equality condition)
    Author.where(id: [david.id, mary.id]).merge(Author.where(id: bob)) # => [bob]
    # Rails 6.1 (both conflict conditions exists, deprecated)
    Author.where(id: david.id..mary.id).merge(Author.where(id: bob)) # => []
    # Rails 6.1 with rewhere to migrate to Rails 7.0's behavior
    Author.where(id: david.id..mary.id).merge(Author.where(id: bob), rewhere: true) # => [bob]
    # Rails 7.0 (same behavior with IN clause, mergee side condition is consistently replaced)
    Author.where(id: [david.id, mary.id]).merge(Author.where(id: bob)) # => [bob]
    Author.where(id: david.id..mary.id).merge(Author.where(id: bob)) # => [bob]
    ```

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

*   Remove deprecated enumeration of `ActiveModel::Errors` instances as a Hash.

*   Remove deprecated `ActiveModel::Errors#to_h`.

*   Remove deprecated `ActiveModel::Errors#slice!`.

*   Remove deprecated `ActiveModel::Errors#values`.

*   Remove deprecated `ActiveModel::Errors#keys`.

*   Remove deprecated `ActiveModel::Errors#to_xml`.

*   Remove deprecated support concat errors to `ActiveModel::Errors#messages`.

*   Remove deprecated support to `clear` errors from `ActiveModel::Errors#messages`.

*   Remove deprecated support to `delete` errors from `ActiveModel::Errors#messages`.

*   Remove deprecated support to use `[]=` in `ActiveModel::Errors#messages`.

*   Remove support to Marshal and YAML load Rails 5.x error format.

*   Remove support to Marshal load Rails 5.x `ActiveModel::AttributeSet` format.

### Deprecations

### Notable changes

Active Support
--------------

Please refer to the [Changelog][active-support] for detailed changes.

### Removals

*   Remove deprecated `config.active_support.use_sha1_digests`.

*   Remove deprecated `URI.parser`.

*   Remove deprecated support to use `Range#include?` to check the inclusion of a value in
    a date time range is deprecated.

*   Remove deprecated `ActiveSupport::Multibyte::Unicode.default_normalization_form`.

### Deprecations

*   Deprecate passing a format to `#to_s` in favor of `#to_fs` in `Array`, `Range`, `Date`, `DateTime`, `Time`,
    `BigDecimal`, `Float` and, `Integer`.

    This deprecation is to allow Rails application to take advantage of a Ruby 3.1
    [optimization](https://github.com/ruby/ruby/commit/b08dacfea39ad8da3f1fd7fdd0e4538cc892ec44) that makes
    interpolation of some types of objects faster.

    New applications will not have the `#to_s` method overridden on those classes, existing applications can use
    `config.active_support.disable_to_s_conversion`.

### Notable changes

Active Job
----------

Please refer to the [Changelog][active-job] for detailed changes.

### Removals

*   Removed deprecated behavior that was not halting `after_enqueue`/`after_perform` callbacks when a
    previous callback was halted with `throw :abort`.

*   Remove deprecated `:return_false_on_aborted_enqueue` option.

### Deprecations

*   Deprecated `Rails.config.active_job.skip_after_callbacks_if_terminated`.

### Notable changes

Action Text
----------

Please refer to the [Changelog][action-text] for detailed changes.

### Removals

### Deprecations

### Notable changes

Action Mailbox
----------

Please refer to the [Changelog][action-mailbox] for detailed changes.

### Removals

*   Removed deprecated `Rails.application.credentials.action_mailbox.mailgun_api_key`.

*   Removed deprecated environment variable `MAILGUN_INGRESS_API_KEY`.

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

[railties]:       https://github.com/rails/rails/blob/7-0-stable/railties/CHANGELOG.md
[action-pack]:    https://github.com/rails/rails/blob/7-0-stable/actionpack/CHANGELOG.md
[action-view]:    https://github.com/rails/rails/blob/7-0-stable/actionview/CHANGELOG.md
[action-mailer]:  https://github.com/rails/rails/blob/7-0-stable/actionmailer/CHANGELOG.md
[action-cable]:   https://github.com/rails/rails/blob/7-0-stable/actioncable/CHANGELOG.md
[active-record]:  https://github.com/rails/rails/blob/7-0-stable/activerecord/CHANGELOG.md
[active-storage]: https://github.com/rails/rails/blob/7-0-stable/activestorage/CHANGELOG.md
[active-model]:   https://github.com/rails/rails/blob/7-0-stable/activemodel/CHANGELOG.md
[active-support]: https://github.com/rails/rails/blob/7-0-stable/activesupport/CHANGELOG.md
[active-job]:     https://github.com/rails/rails/blob/7-0-stable/activejob/CHANGELOG.md
[action-text]:    https://github.com/rails/rails/blob/7-0-stable/actiontext/CHANGELOG.md
[action-mailbox]: https://github.com/rails/rails/blob/7-0-stable/actionmailbox/CHANGELOG.md
[guides]:         https://github.com/rails/rails/blob/7-0-stable/guides/CHANGELOG.md
