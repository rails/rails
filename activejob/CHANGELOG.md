*   Fix `ActiveJob.perform_all_later` to respect `job_class.enqueue_after_transaction_commit`.

    Previously, `perform_all_later` would enqueue all jobs immediately, even if
    they had `enqueue_after_transaction_commit = true`. Now it correctly defers
    jobs with this setting until after transaction commits, matching the behavior
    of `perform_later`.

    *OuYangJinTing*

*   Fix using custom serializers with `ActiveJob::Arguments.serialize` when
    `ActiveJob::Base` hasn't been loaded.

    *Hartley McGuire*

Please check [8-1-stable](https://github.com/rails/rails/blob/8-1-stable/activejob/CHANGELOG.md) for previous changes.
