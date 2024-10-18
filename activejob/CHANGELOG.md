## Rails 8.0.0.beta1 (September 26, 2024) ##

*   Deprecate `sucker_punch` as an adapter option.

    If you're using this adapter, change to `adapter: async` for the same functionality.

    *Dino Maric, zzak*

*   Use `RAILS_MAX_THREADS` in `ActiveJob::AsyncAdapter`. If it is not set, use 5 as default.

    *heka1024*

*   Now `config.active_job.enqueue_after_transaction_commit` default value is `true` and will accept only boolean values.

    Adapters do not longer need to implement the `enqueue_after_transaction_commit?` method and can not use it to
    change the global behavior.

    Specific jobs can still change the value between `true` and `false`.

    In general is not recommended to set the value to `false` because enqueuing jobs from inside a transaction
    can cause them to potentially be picked and ran by another process before the transaction is committed.

    *Juanjo Bazán*


Please check [7-2-stable](https://github.com/rails/rails/blob/7-2-stable/activejob/CHANGELOG.md) for previous changes.
