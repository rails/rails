*   Jobs are now enqueued after transaction commit.

    This fixes that jobs would surprisingly run against uncommitted and
    rolled-back records.

    New Rails 8.2 apps (and apps upgrading to `config.load_defaults "8.2"`)
    default `ActiveJob::Base.enqueue_after_transaction_commit` to true.
    Uncomment the setting in `config/initializers/new_framework_defaults_8_2.rb`
    to opt in.

    *mugitti9*

*   Deprecate built-in `sneakers` adapter.

    *Dino Maric*

*   Fix using custom serializers with `ActiveJob::Arguments.serialize` when
    `ActiveJob::Base` hasn't been loaded.

    *Hartley McGuire*

Please check [8-1-stable](https://github.com/rails/rails/blob/8-1-stable/activejob/CHANGELOG.md) for previous changes.
