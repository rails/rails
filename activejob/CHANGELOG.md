*   Remove `sucker_punch` as an adapter option [since author himself recommends using AJ's own AsyncAdapter](https://github.com/brandonhilkert/sucker_punch?tab=readme-ov-file#faq).
    If you're using this adapter, change to `adapter: async` for the same functionality.

    *Dino Maric*

*   Use `RAILS_MAX_THREADS` in `ActiveJob::AsyncAdapter`. If it is not set, use 5 as default.

    *heka1024*

Please check [7-2-stable](https://github.com/rails/rails/blob/7-2-stable/activejob/CHANGELOG.md) for previous changes.
