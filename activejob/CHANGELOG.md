*   Support second-level precision for `assert_enqueued_with`

    Fixes #52478.

    *Steve Polito*

*   Use `RAILS_MAX_THREADS` in `ActiveJob::AsyncAdapter`. If it is not set, use 5 as default.

    *heka1024*

Please check [7-2-stable](https://github.com/rails/rails/blob/7-2-stable/activejob/CHANGELOG.md) for previous changes.
