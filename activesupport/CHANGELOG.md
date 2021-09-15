## Rails 7.0.0.alpha2 (September 15, 2021) ##

*   No changes.


## Rails 7.0.0.alpha1 (September 15, 2021) ##

*   `ActiveSupport::Dependencies` no longer installs a `const_missing` hook. Before this, you could push to the autoload paths and have constants autoloaded. This feature, known as the `classic` autoloader, has been removed.

    *Xavier Noria*

*   Private internal classes of `ActiveSupport::Dependencies` have been deleted, like `ActiveSupport::Dependencies::Reference`, `ActiveSupport::Dependencies::Blamable`, and others.

    *Xavier Noria*

*   The private API of `ActiveSupport::Dependencies` has been deleted. That includes methods like `hook!`, `unhook!`, `depend_on`, `require_or_load`, `mechanism`, and many others.

    *Xavier Noria*

*   Improves the performance of `ActiveSupport::NumberHelper` formatters by avoiding the use of exceptions as flow control.

    *Mike Dalessio*

*   Removed rescue block from `ActiveSupport::Cache::RedisCacheStore#handle_exception`

    Previously, if you provided a `error_handler` to `redis_cache_store`, any errors thrown by
    the error handler would be rescued and logged only. Removed the `rescue` clause from `handle_exception`
    to allow these to be thrown.

    *Nicholas A. Stuart*

*   Allow entirely opting out of deprecation warnings.

    Previously if you did `app.config.active_support.deprecation = :silence`, some work would
    still be done on each call to `ActiveSupport::Deprecation.warn`. In very hot paths, this could
    cause performance issues.

    Now, you can make `ActiveSupport::Deprecation.warn` a no-op:

    ```ruby
    config.active_support.report_deprecations = false
    ```

    This is the default in production for new apps. It is the equivalent to:

    ```ruby
    config.active_support.deprecation = :silence
    config.active_support.disallowed_deprecation = :silence
    ```

    but will take a more optimised code path.

    *Alex Ghiculescu*

*   Faster tests by parallelizing only when overhead is justified by the number
    of them.

    Running tests in parallel adds overhead in terms of database
    setup and fixture loading. Now, Rails will only parallelize test executions when
    there are enough tests to make it worth it.

    This threshold is 50 by default, and is configurable via config setting in
    your test.rb:

    ```ruby
    config.active_support.test_parallelization_threshold = 100
    ```

    It's also configurable at the test case level:

    ```ruby
    class ActiveSupport::TestCase
      parallelize threshold: 100
    end
    ```

    *Jorge Manrubia*

*   OpenSSL constants are now used for Digest computations.

    *Dirkjan Bussink*

*   `TimeZone.iso8601` now accepts valid ordinal values similar to Ruby's `Date._iso8601` method.
    A valid ordinal value will be converted to an instance of `TimeWithZone` using the `:year`
    and `:yday` fragments returned from `Date._iso8601`.

    ```ruby
    twz = ActiveSupport::TimeZone["Eastern Time (US & Canada)"].iso8601("21087")
    twz.to_a[0, 6] == [0, 0, 0, 28, 03, 2021]
    ```

    *Steve Laing*

*   `Time#change` and methods that call it (e.g. `Time#advance`) will now
    return a `Time` with the timezone argument provided, if the caller was
    initialized with a timezone argument.

    Fixes [#42467](https://github.com/rails/rails/issues/42467).

    *Alex Ghiculescu*

*   Allow serializing any module or class to JSON by name.

    *Tyler Rick*, *Zachary Scott*

*   Raise `ActiveSupport::EncryptedFile::MissingKeyError` when the
    `RAILS_MASTER_KEY` environment variable is blank (e.g. `""`).

    *Sunny Ripert*

*   The `from:` option is added to `ActiveSupport::TestCase#assert_no_changes`.

    It permits asserting on the initial value that is expected not to change.

    ```ruby
    assert_no_changes -> { Status.all_good? }, from: true do
      post :create, params: { status: { ok: true } }
    end
    ```

    *George Claghorn*

*   Deprecate `ActiveSupport::SafeBuffer`'s incorrect implicit conversion of objects into string.

    Except for a few methods like `String#%`, objects must implement `#to_str`
    to be implicitly converted to a String in string operations. In some
    circumstances `ActiveSupport::SafeBuffer` was incorrectly calling the
    explicit conversion method (`#to_s`) on them. This behavior is now
    deprecated.

    *Jean Boussier*

*   Allow nested access to keys on `Rails.application.credentials`.

    Previously only top level keys in `credentials.yml.enc` could be accessed with method calls. Now any key can.

    For example, given these secrets:

    ```yml
    aws:
      access_key_id: 123
      secret_access_key: 345
    ```

    `Rails.application.credentials.aws.access_key_id` will now return the same thing as
    `Rails.application.credentials.aws[:access_key_id]`.

    *Alex Ghiculescu*

*   Added a faster and more compact `ActiveSupport::Cache` serialization format.

    It can be enabled with `config.active_support.cache_format_version = 7.0` or
    `config.load_defaults 7.0`. Regardless of the configuration Active Support
    7.0 can read cache entries serialized by Active Support 6.1 which allows to
    upgrade without invalidating the cache. However Rails 6.1 can't read the
    new format, so all readers must be upgraded before the new format is enabled.

    *Jean Boussier*

*   Add `Enumerable#sole`, per `ActiveRecord::FinderMethods#sole`.  Returns the
    sole item of the enumerable, raising if no items are found, or if more than
    one is.

    *Asherah Connor*

*   Freeze `ActiveSupport::Duration#parts` and remove writer methods.

    Durations are meant to be value objects and should not be mutated.

    *Andrew White*

*   Fix `ActiveSupport::TimeZone#utc_to_local` with fractional seconds.

    When `utc_to_local_returns_utc_offset_times` is false and the time
    instance had fractional seconds the new UTC time instance was out by
    a factor of 1,000,000 as the `Time.utc` constructor takes a usec
    value and not a fractional second value.

    *Andrew White*

*   Add `expires_at` argument to `ActiveSupport::Cache` `write` and `fetch` to set a cache entry TTL as an absolute time.

    ```ruby
    Rails.cache.write(key, value, expires_at: Time.now.at_end_of_hour)
    ```

    *Jean Boussier*

*   Deprecate `ActiveSupport::TimeWithZone.name` so that from Rails 7.1 it will use the default implementation.

    *Andrew White*

*   Deprecates Rails custom `Enumerable#sum` and `Array#sum` in favor of Ruby's native implementation which
    is considerably faster.

    Ruby requires an initializer for non-numeric type as per examples below:

    ```ruby
    %w[foo bar].sum('')
    # instead of %w[foo bar].sum

    [[1, 2], [3, 4, 5]].sum([])
    # instead of [[1, 2], [3, 4, 5]].sum
    ```

    *Alberto Mota*

*   Tests parallelization is now disabled when running individual files to prevent the setup overhead.

    It can still be enforced if the environment variable `PARALLEL_WORKERS` is present and set to a value greater than 1.

    *Ricardo Díaz*

*   Fix proxying keyword arguments in `ActiveSupport::CurrentAttributes`.

    *Marcin Kołodziej*

*   Add `Enumerable#maximum` and `Enumerable#minimum` to easily calculate the maximum or minimum from extracted
    elements of an enumerable.

    ```ruby
    payments = [Payment.new(5), Payment.new(15), Payment.new(10)]

    payments.minimum(:price) # => 5
    payments.maximum(:price) # => 15
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

*   Consume dalli’s `cache_nils` configuration as `ActiveSupport::Cache`'s `skip_nil` when using `MemCacheStore`.

    *Ritikesh G*

*   Add `RedisCacheStore#stats` method similar to `MemCacheStore#stats`. Calls `redis#info` internally.

    *Ritikesh G*


Please check [6-1-stable](https://github.com/rails/rails/blob/6-1-stable/activesupport/CHANGELOG.md) for previous changes.
