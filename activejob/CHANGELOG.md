*   Remove deprecated `sidekiq` Active Job adapter.

    The adapter is available in the `sidekiq` gem.

    *Wojciech Wnętrzak*

*   Deprecate built-in `delayed_job` adapter.

    If you're using this adapter, upgrade to `delayed_job` 4.2.0 or later to use the `delayed_job` gem's adapter.

    *Dino Maric, David Genord II, Wojciech Wnętrzak*

*   Deprecate built-in `backburner` adapter.

    *Dino Maric, Nathan Esquenazi, Earlopain*

*   Jobs are now enqueued after transaction commit.

    This fixes that jobs would surprisingly run against uncommitted and
    rolled-back records.

    New Rails 8.2 apps (and apps upgrading to `config.load_defaults "8.2"`)
    have `config.active_job.enqueue_after_transaction_commit = true` by default.
    Uncomment the setting in `config/initializers/new_framework_defaults_8_2.rb`
    to opt in.

    *mugitti9*

*   Un-deprecate the global `config.active_job.enqueue_after_transaction_commit`
    toggle for app-wide overrides. It was deprecated in Rails 8.0 (when the
    symbol values were removed) and made non-functional in 8.1. It now works
    as a boolean config again.

    *Jeremy Daer*

*   Deprecate built-in `sneakers` adapter.

    *Dino Maric*

*   Fix using custom serializers with `ActiveJob::Arguments.serialize` when
    `ActiveJob::Base` hasn't been loaded.

    *Hartley McGuire*

Please check [8-1-stable](https://github.com/rails/rails/blob/8-1-stable/activejob/CHANGELOG.md) for previous changes.
