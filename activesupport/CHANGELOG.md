*   Fixes `CurrentAttributes.set` when attribute readers are made private in
    order to expose a limited interface.

    *Cameron Bothner*

*   Raises an `ArgumentError` when the first argument of `ActiveSupport::Notification.subscribe` is
    invalid.

    *Vipul A M*

*   `HashWithIndifferentAccess#deep_transform_keys` now returns a `HashWithIndifferentAccess` instead of a `Hash`.

    *Nathaniel Woodthorpe*

*   consume dalli’s `cache_nils` configuration as `ActiveSupport::Cache`'s `skip_nil` when using `MemCacheStore`.

    *Ritikesh G*

*   add `RedisCacheStore#stats` method similar to `MemCacheStore#stats`. Calls `redis#info` internally.

    *Ritikesh G*


Please check [6-1-stable](https://github.com/rails/rails/blob/6-1-stable/activesupport/CHANGELOG.md) for previous changes.
