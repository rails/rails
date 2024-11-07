## Rails 8.0.0 (November 07, 2024) ##

*   No changes.


## Rails 8.0.0.rc2 (October 30, 2024) ##

*   No changes.


## Rails 8.0.0.rc1 (October 19, 2024) ##

*   Remove deprecated `config.active_job.use_big_decimal_serializer`.

    *Rafael Mendonça França*


## Rails 8.0.0.beta1 (September 26, 2024) ##

*   Deprecate `sucker_punch` as an adapter option.

    If you're using this adapter, change to `adapter: async` for the same functionality.

    *Dino Maric, zzak*

*   Use `RAILS_MAX_THREADS` in `ActiveJob::AsyncAdapter`. If it is not set, use 5 as default.

    *heka1024*

Please check [7-2-stable](https://github.com/rails/rails/blob/7-2-stable/activejob/CHANGELOG.md) for previous changes.
