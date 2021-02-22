*   Fix proxying keyword arguments in `ActiveSupport::CurrentAttributes`.

    *Marcin Kołodziej*

*   Add `Enumerable#maximum` and `Enumerable#minimum` to easily calculate the maximum or minimum from extracted
    elements of an enumerable.

    ```ruby
    payments = [Payment.new(5), Payment.new(15), Payment.new(10)]

    payments.minimum(:price) # => 5
    payments.maximum(:price) # => 20
    ```

    This also allows passing enumerables to `fresh_when` and `stale?` in Action Controller.
    See PR [#41404](https://github.com/rails/rails/pull/41404) for an example.

    *Ayrton De Craene*

*   `ActiveSupport::Cache::MemCacheStore` now accepts an explicit `nil` for its `addresses` argument.

    ```ruby
    config.cache_store = :mem_cache_store, nil

    # is now equivalent to

    config.cache_store = :mem_cache_store

    # and is also equivalent to

    config.cache_store = :mem_cache_store, ENV["MEMCACHE_SERVERS"] || "localhost:11211"

    # which is the fallback behavior of Dalli
    ```

    This helps those migrating from `:dalli_store`, where an explicit `nil` was permitted.

    *Michael Overmeyer*

*   Add `Enumerable#in_order_of` to put an Enumerable in a certain order by a key.

    *DHH*

*   `ActiveSupport::Inflector.camelize` behaves expected when provided a symbol `:upper` or `:lower` argument. Matches
    `String#camelize` behavior.

    *Alex Ghiculescu*

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
