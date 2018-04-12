*   Fix bug where `ActiveSupport::Cache` will massively inflate the storage
    size when compression is enabled (which is true by default). This patch
    does not attempt to repair existing data: please manually flush the cache
    to clear out the problematic entries.

    *Godfrey Chan*


## Rails 5.2.0 (April 09, 2018) ##

*   Caching: MemCache and Redis `read_multi` and `fetch_multi` speedup.
    Read from the local in-memory cache before consulting the backend.

    *Gabriel Sobrinho*

*   Return all mappings for a timezone identifier in `country_zones`.

    Some timezones like `Europe/London` have multiple mappings in
    `ActiveSupport::TimeZone::MAPPING` so return all of them instead
    of the first one found by using `Hash#value`. e.g:

        # Before
        ActiveSupport::TimeZone.country_zones("GB") # => ["Edinburgh"]

        # After
        ActiveSupport::TimeZone.country_zones("GB") # => ["Edinburgh", "London"]

    Fixes #31668.

    *Andrew White*

*   Add support for connection pooling on RedisCacheStore.

    *fatkodima*

*   Support hash as first argument in `assert_difference`. This allows to specify multiple
    numeric differences in the same assertion.

        assert_difference ->{ Article.count } => 1, ->{ Post.count } => 2

    *Julien Meichelbeck*

*   Add missing instrumentation for `read_multi` in `ActiveSupport::Cache::Store`.

    *Ignatius Reza Lesmana*

*   `assert_changes` will always assert that the expression changes,
    regardless of `from:` and `to:` argument combinations.

    *Daniel Ma*

*   Use SHA-1 to generate non-sensitive digests, such as the ETag header.

    Enabled by default for new apps; upgrading apps can opt in by setting
    `config.active_support.use_sha1_digests = true`.

    *Dmitri Dolguikh*, *Eugene Kenny*

*   Changed default behaviour of `ActiveSupport::SecurityUtils.secure_compare`,
    to make it not leak length information even for variable length string.

    Renamed old `ActiveSupport::SecurityUtils.secure_compare` to `fixed_length_secure_compare`,
    and started raising `ArgumentError` in case of length mismatch of passed strings.

    *Vipul A M*

*   Make `ActiveSupport::TimeZone.all` return only time zones that are in
    `ActiveSupport::TimeZone::MAPPING`.

    Fixes #7245.

    *Chris LaRose*

*   MemCacheStore: Support expiring counters.

    Pass `expires_in: [seconds]` to `#increment` and `#decrement` options
    to set the Memcached TTL (time-to-live) if the counter doesn't exist.
    If the counter exists, Memcached doesn't extend its expiry when it's
    incremented or decremented.

    ```
    Rails.cache.increment("my_counter", 1, expires_in: 2.minutes)
    ```

    *Takumasa Ochi*

*   Handle `TZInfo::AmbiguousTime` errors.

    Make `ActiveSupport::TimeWithZone` match Ruby's handling of ambiguous
    times by choosing the later period, e.g.

    Ruby:
    ```
    ENV["TZ"] = "Europe/Moscow"
    Time.local(2014, 10, 26, 1, 0, 0)   # => 2014-10-26 01:00:00 +0300
    ```

    Before:
    ```
    >> "2014-10-26 01:00:00".in_time_zone("Moscow")
    TZInfo::AmbiguousTime: 26/10/2014 01:00 is an ambiguous local time.
    ```

    After:
    ```
    >> "2014-10-26 01:00:00".in_time_zone("Moscow")
    => Sun, 26 Oct 2014 01:00:00 MSK +03:00
    ```

    Fixes #17395.

    *Andrew White*

*   Redis cache store.

    ```
    # Defaults to `redis://localhost:6379/0`. Only use for dev/test.
    config.cache_store = :redis_cache_store

    # Supports all common cache store options (:namespace, :compress,
    # :compress_threshold, :expires_in, :race_condition_ttl) and all
    # Redis options.
    cache_password = Rails.application.secrets.redis_cache_password
    config.cache_store = :redis_cache_store, driver: :hiredis,
      namespace: 'myapp-cache', compress: true, timeout: 1,
      url: "redis://:#{cache_password}@myapp-cache-1:6379/0"

    # Supports Redis::Distributed with multiple hosts
    config.cache_store = :redis_cache_store, driver: :hiredis
      namespace: 'myapp-cache', compress: true,
      url: %w[
        redis://myapp-cache-1:6379/0
        redis://myapp-cache-1:6380/0
        redis://myapp-cache-2:6379/0
        redis://myapp-cache-2:6380/0
        redis://myapp-cache-3:6379/0
        redis://myapp-cache-3:6380/0
      ]

    # Or pass a builder block
    config.cache_store = :redis_cache_store,
      namespace: 'myapp-cache', compress: true,
      redis: -> { Redis.new … }
    ```

    Deployment note: Take care to use a *dedicated Redis cache* rather
    than pointing this at your existing Redis server. It won't cope well
    with mixed usage patterns and it won't expire cache entries by default.

    Redis cache server setup guide: https://redis.io/topics/lru-cache

    *Jeremy Daer*

*   Cache: Enable compression by default for values > 1kB.

    Compression has long been available, but opt-in and at a 16kB threshold.
    It wasn't enabled by default due to CPU cost. Today it's cheap and typical
    cache data is eminently compressible, such as HTML or JSON fragments.
    Compression dramatically reduces Memcached/Redis mem usage, which means
    the same cache servers can store more data, which means higher hit rates.

    To disable compression, pass `compress: false` to the initializer.

    *Jeremy Daer*

*   Allow `Range#include?` on TWZ ranges.

    In #11474 we prevented TWZ ranges being iterated over which matched
    Ruby's handling of Time ranges and as a consequence `include?`
    stopped working with both Time ranges and TWZ ranges. However in
    ruby/ruby@b061634 support was added for `include?` to use `cover?`
    for 'linear' objects. Since we have no way of making Ruby consider
    TWZ instances as 'linear' we have to override `Range#include?`.

    Fixes #30799.

    *Andrew White*

*   Fix acronym support in `humanize`.

    Acronym inflections are stored with lowercase keys in the hash but
    the match wasn't being lowercased before being looked up in the hash.
    This shouldn't have any performance impact because before it would
    fail to find the acronym and perform the `downcase` operation anyway.

    Fixes #31052.

    *Andrew White*

*   Add same method signature for `Time#prev_year` and `Time#next_year`
    in accordance with `Date#prev_year`, `Date#next_year`.

    Allows pass argument for `Time#prev_year` and `Time#next_year`.

    Before:
    ```
    Time.new(2017, 9, 16, 17, 0).prev_year    # => 2016-09-16 17:00:00 +0300
    Time.new(2017, 9, 16, 17, 0).prev_year(1)
    # => ArgumentError: wrong number of arguments (given 1, expected 0)

    Time.new(2017, 9, 16, 17, 0).next_year    # => 2018-09-16 17:00:00 +0300
    Time.new(2017, 9, 16, 17, 0).next_year(1)
    # => ArgumentError: wrong number of arguments (given 1, expected 0)
    ```

    After:
    ```
    Time.new(2017, 9, 16, 17, 0).prev_year    # => 2016-09-16 17:00:00 +0300
    Time.new(2017, 9, 16, 17, 0).prev_year(1) # => 2016-09-16 17:00:00 +0300

    Time.new(2017, 9, 16, 17, 0).next_year    # => 2018-09-16 17:00:00 +0300
    Time.new(2017, 9, 16, 17, 0).next_year(1) # => 2018-09-16 17:00:00 +0300
    ```

    *bogdanvlviv*

*   Add same method signature for `Time#prev_month` and `Time#next_month`
    in accordance with `Date#prev_month`, `Date#next_month`.

    Allows pass argument for `Time#prev_month` and `Time#next_month`.

    Before:
    ```
    Time.new(2017, 9, 16, 17, 0).prev_month    # => 2017-08-16 17:00:00 +0300
    Time.new(2017, 9, 16, 17, 0).prev_month(1)
    # => ArgumentError: wrong number of arguments (given 1, expected 0)

    Time.new(2017, 9, 16, 17, 0).next_month    # => 2017-10-16 17:00:00 +0300
    Time.new(2017, 9, 16, 17, 0).next_month(1)
    # => ArgumentError: wrong number of arguments (given 1, expected 0)
    ```

    After:
    ```
    Time.new(2017, 9, 16, 17, 0).prev_month    # => 2017-08-16 17:00:00 +0300
    Time.new(2017, 9, 16, 17, 0).prev_month(1) # => 2017-08-16 17:00:00 +0300

    Time.new(2017, 9, 16, 17, 0).next_month    # => 2017-10-16 17:00:00 +0300
    Time.new(2017, 9, 16, 17, 0).next_month(1) # => 2017-10-16 17:00:00 +0300
    ```

    *bogdanvlviv*

*   Add same method signature for `Time#prev_day` and `Time#next_day`
    in accordance with `Date#prev_day`, `Date#next_day`.

    Allows pass argument for `Time#prev_day` and `Time#next_day`.

    Before:
    ```
    Time.new(2017, 9, 16, 17, 0).prev_day    # => 2017-09-15 17:00:00 +0300
    Time.new(2017, 9, 16, 17, 0).prev_day(1)
    # => ArgumentError: wrong number of arguments (given 1, expected 0)

    Time.new(2017, 9, 16, 17, 0).next_day    # => 2017-09-17 17:00:00 +0300
    Time.new(2017, 9, 16, 17, 0).next_day(1)
    # => ArgumentError: wrong number of arguments (given 1, expected 0)
    ```

    After:
    ```
    Time.new(2017, 9, 16, 17, 0).prev_day    # => 2017-09-15 17:00:00 +0300
    Time.new(2017, 9, 16, 17, 0).prev_day(1) # => 2017-09-15 17:00:00 +0300

    Time.new(2017, 9, 16, 17, 0).next_day    # => 2017-09-17 17:00:00 +0300
    Time.new(2017, 9, 16, 17, 0).next_day(1) # => 2017-09-17 17:00:00 +0300
    ```

    *bogdanvlviv*

*   `IO#to_json` now returns the `to_s` representation, rather than
    attempting to convert to an array. This fixes a bug where `IO#to_json`
    would raise an `IOError` when called on an unreadable object.

    Fixes #26132.

    *Paul Kuruvilla*

*   Remove deprecated `halt_callback_chains_on_return_false` option.

    *Rafael Mendonça França*

*   Remove deprecated `:if` and `:unless` string filter for callbacks.

    *Rafael Mendonça França*

*   `Hash#slice` now falls back to Ruby 2.5+'s built-in definition if defined.

    *Akira Matsuda*

*   Deprecate `secrets.secret_token`.

    The architecture for secrets had a big upgrade between Rails 3 and Rails 4,
    when the default changed from using `secret_token` to `secret_key_base`.

    `secret_token` has been soft deprecated in documentation for four years
    but is still in place to support apps created before Rails 4.
    Deprecation warnings have been added to help developers upgrade their
    applications to `secret_key_base`.

    *claudiob*, *Kasper Timm Hansen*

*   Return an instance of `HashWithIndifferentAccess` from `HashWithIndifferentAccess#transform_keys`.

    *Yuji Yaginuma*

*   Add key rotation support to `MessageEncryptor` and `MessageVerifier`.

    This change introduces a `rotate` method to both the `MessageEncryptor` and
    `MessageVerifier` classes. This method accepts the same arguments and
    options as the given classes' constructor. The `encrypt_and_verify` method
    for `MessageEncryptor` and the `verified` method for `MessageVerifier` also
    accept an optional keyword argument `:on_rotation` block which is called
    when a rotated instance is used to decrypt or verify the message.

    *Michael J Coyne*

*   Deprecate `Module#reachable?` method.

    *bogdanvlviv*

*   Add `config/credentials.yml.enc` to store production app secrets.

    Allows saving any authentication credentials for third party services
    directly in repo encrypted with `config/master.key` or `ENV["RAILS_MASTER_KEY"]`.

    This will eventually replace `Rails.application.secrets` and the encrypted
    secrets introduced in Rails 5.1.

    *DHH*, *Kasper Timm Hansen*

*   Add `ActiveSupport::EncryptedFile` and `ActiveSupport::EncryptedConfiguration`.

    Allows for stashing encrypted files or configuration directly in repo by
    encrypting it with a key.

    Backs the new credentials setup above, but can also be used independently.

    *DHH*, *Kasper Timm Hansen*

*   `Module#delegate_missing_to` now raises `DelegationError` if target is nil,
    similar to `Module#delegate`.

    *Anton Khamets*

*   Update `String#camelize` to provide feedback when wrong option is passed.

    `String#camelize` was returning nil without any feedback when an
    invalid option was passed as a parameter.

    Previously:

        'one_two'.camelize(true)
        # => nil

    Now:

        'one_two'.camelize(true)
        # => ArgumentError: Invalid option, use either :upper or :lower.

    *Ricardo Díaz*

*   Fix modulo operations involving durations.

    Rails 5.1 introduced `ActiveSupport::Duration::Scalar` as a wrapper
    around numeric values as a way of ensuring a duration was the outcome of
    an expression. However, the implementation was missing support for modulo
    operations. This support has now been added and should result in a duration
    being returned from expressions involving modulo operations.

    Prior to Rails 5.1:

        5.minutes % 2.minutes
        # => 60

    Now:

        5.minutes % 2.minutes
        # => 1 minute

    Fixes #29603 and #29743.

    *Sayan Chakraborty*, *Andrew White*

*   Fix division where a duration is the denominator.

    PR #29163 introduced a change in behavior when a duration was the denominator
    in a calculation - this was incorrect as dividing by a duration should always
    return a `Numeric`. The behavior of previous versions of Rails has been restored.

    Fixes #29592.

    *Andrew White*

*   Add purpose and expiry support to `ActiveSupport::MessageVerifier` and
   `ActiveSupport::MessageEncryptor`.

    For instance, to ensure a message is only usable for one intended purpose:

        token = @verifier.generate("x", purpose: :shipping)

        @verifier.verified(token, purpose: :shipping) # => "x"
        @verifier.verified(token)                     # => nil

    Or make it expire after a set time:

        @verifier.generate("x", expires_in: 1.month)
        @verifier.generate("y", expires_at: Time.now.end_of_year)

    Showcased with `ActiveSupport::MessageVerifier`, but works the same for
    `ActiveSupport::MessageEncryptor`'s `encrypt_and_sign` and `decrypt_and_verify`.

    Pull requests: #29599, #29854

    *Assain Jaleel*

*   Make the order of `Hash#reverse_merge!` consistent with `HashWithIndifferentAccess`.

    *Erol Fornoles*

*   Add `freeze_time` helper which freezes time to `Time.now` in tests.

    *Prathamesh Sonpatki*

*   Default `ActiveSupport::MessageEncryptor` to use AES 256 GCM encryption.

    On for new Rails 5.2 apps. Upgrading apps can find the config as a new
    framework default.

    *Assain Jaleel*

*   Cache: `write_multi`.

        Rails.cache.write_multi foo: 'bar', baz: 'qux'

    Plus faster fetch_multi with stores that implement `write_multi_entries`.
    Keys that aren't found may be written to the cache store in one shot
    instead of separate writes.

    The default implementation simply calls `write_entry` for each entry.
    Stores may override if they're capable of one-shot bulk writes, like
    Redis `MSET`.

    *Jeremy Daer*

*   Add default option to module and class attribute accessors.

        mattr_accessor :settings, default: {}

    Works for `mattr_reader`, `mattr_writer`, `cattr_accessor`, `cattr_reader`,
    and `cattr_writer` as well.

    *Genadi Samokovarov*

*   Add `Date#prev_occurring` and `Date#next_occurring` to return specified next/previous occurring day of week.

    *Shota Iguchi*

*   Add default option to `class_attribute`.

    Before:

        class_attribute :settings
        self.settings = {}

    Now:

        class_attribute :settings, default: {}

    *DHH*

*   `#singularize` and `#pluralize` now respect uncountables for the specified locale.

    *Eilis Hamilton*

*   Add `ActiveSupport::CurrentAttributes` to provide a thread-isolated attributes singleton.
    Primary use case is keeping all the per-request attributes easily available to the whole system.

    *DHH*

*   Fix implicit coercion calculations with scalars and durations.

    Previously, calculations where the scalar is first would be converted to a duration
    of seconds, but this causes issues with dates being converted to times, e.g:

        Time.zone = "Beijing"           # => Asia/Shanghai
        date = Date.civil(2017, 5, 20)  # => Mon, 20 May 2017
        2 * 1.day                       # => 172800 seconds
        date + 2 * 1.day                # => Mon, 22 May 2017 00:00:00 CST +08:00

    Now, the `ActiveSupport::Duration::Scalar` calculation methods will try to maintain
    the part structure of the duration where possible, e.g:

        Time.zone = "Beijing"           # => Asia/Shanghai
        date = Date.civil(2017, 5, 20)  # => Mon, 20 May 2017
        2 * 1.day                       # => 2 days
        date + 2 * 1.day                # => Mon, 22 May 2017

    Fixes #29160, #28970.

    *Andrew White*

*   Add support for versioned cache entries. This enables the cache stores to recycle cache keys, greatly saving
    on storage in cases with frequent churn. Works together with the separation of `#cache_key` and `#cache_version`
    in Active Record and its use in Action Pack's fragment caching.

    *DHH*

*   Pass gem name and deprecation horizon to deprecation notifications.

    *Willem van Bergen*

*   Add support for `:offset` and `:zone` to `ActiveSupport::TimeWithZone#change`.

    *Andrew White*

*   Add support for `:offset` to `Time#change`.

    Fixes #28723.

    *Andrew White*

*   Add `fetch_values` for `HashWithIndifferentAccess`.

    The method was originally added to `Hash` in Ruby 2.3.0.

    *Josh Pencheon*


Please check [5-1-stable](https://github.com/rails/rails/blob/5-1-stable/activesupport/CHANGELOG.md) for previous changes.
