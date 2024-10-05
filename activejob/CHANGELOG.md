## Rails 8.0.0.beta1 (September 26, 2024) ##

*   Deprecate `sucker_punch` as an adapter option.

    If you're using this adapter, change to `adapter: async` for the same functionality.

    *Dino Maric, zzak*

*   Use `RAILS_MAX_THREADS` in `ActiveJob::AsyncAdapter`. If it is not set, use 5 as default.

    *heka1024*

*   Report errors that happen to the Rails error reporter

    *Nick Pezza*

Please check [7-2-stable](https://github.com/rails/rails/blob/7-2-stable/activejob/CHANGELOG.md) for previous changes.
