*   Added option `expires_in_at` to specify cache expiration time:

        Rails.cache.fetch('cache_key', expires_in_at: '00:00') do
           do somethink ...
        end

        or

        Rails.cache.write('cache_key', expires_in_at: '00:00')


    *Maxim Aleynikov*

*   `HashWithIndifferentAccess#deep_transform_keys` now returns a `HashWithIndifferentAccess` instead of a `Hash`.

    *Nathaniel Woodthorpe*

*   consume dalli’s `cache_nils` configuration as `ActiveSupport::Cache`'s `skip_nil` when using `MemCacheStore`.

    *Ritikesh G*


Please check [6-1-stable](https://github.com/rails/rails/blob/6-1-stable/activesupport/CHANGELOG.md) for previous changes.
