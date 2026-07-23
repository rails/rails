*   Preserve sub-second precision when subtracting a `DateTime` from a `Time`.

    `Time - DateTime` converted both sides via `to_f`, so microsecond-level
    `DateTime` values lost precision. The difference is now computed from exact
    rational timestamps, matching `Time.at(DateTime)` and
    `ActiveSupport::TimeWithZone - DateTime`.

    *Said Kaldybaev*

*   Deprecate `ActiveSupport::Cache::RedisCacheStore::DEFAULT_REDIS_OPTIONS`.

    The `redis-client` implementation no longer reads this constant. Pass
    timeout options to `RedisCacheStore` or a configured `RedisClient` instead.

    *Nikita Vasilevsky*

*   Add `#this_quarter?` to Date/Time.

    It returns true if the date/time falls within the current quarter.

    ```ruby
    Date.current #=> Tue, 15 Feb 2000
    Date.new(2000, 3, 31).this_quarter?  # => true
    Date.new(2000, 4, 1).this_quarter?   # => false
    ```

    *Kenta Ishizaki*

*   Added `ActiveSupport::ProxyLogger`.

    The proxy logger, is a logger that forwards all received logs to another
    logger, but has its own independent severity level.

    This is useful when you want some library you have no control over to use
    the same logger as the rest of your application, but to have a different severity
    level because it is logging too much:

    ```ruby
    SomeLibrary.logger = ActiveSupport::ProxyLogger.new(Rails.logger, :error)
    ```

    Almost all of the standard Logger interface is supported.

    *Jean Boussier*

*   Include call options in `Cache#exist?` instrumentation payload,
    consistent with `read`, `write`, and `delete`.

    *Kenta Ishizaki*

*   Declare `assert_not_pattern` as an alias for `refute_pattern`

    *Sean Doyle*

*   `assert_difference`, `assert_no_difference`, `assert_changes`, and
    `assert_no_changes` now raise `ArgumentError` when given an expression that
    is not a callable (like a Proc), String, or Symbol.

    This helps catch issues where you accidentally pass a single static value
    (like `assert_no_changes(a.size)`). The same value would seen before
    and after the block, so no change would ever be found, silently passing
    the assertion even if there *was* an unexpected change.

    To be reevaluated correctly, the expression should wrapped in a lambda like
    `assert_no_changes(-> { a.size })`, or quoted in a String that can be `eval`-ed.

    *Alexander Momchilov*

*   Add `ActiveSupport::Notifications::NullInstrumenter`, a stateless no-op
    instrumenter that executes blocks without publishing any notifications.

    Available via `ActiveSupport::Notifications.null_instrumenter`, this is
    useful for suppressing instrumentation on specific components, such as
    database connections that don't need SQL notification overhead.

    *Rosa Gutierrez*

*   `ActiveSupport::Cache::RedisCacheStore` entirely reimplemented.

    Now depends on the much lighter `redis-client >= 0.28.0` instead of `redis >= 4.0.1`.

    The change shouldn't be noticeable unless the cache is configured with the `:redis` argument.
    In such case it will keep working for now, but will issue a deprecation warning.

    Prefer configuring Redis Cache Store with an `:url` argument instead, but if you need advanced options
    not supported by Redis Cache Store constructor, you can alternatively pass a custom `RedisClient::Config` instance
    via the `:client` argument.

    *Jean Boussier*

*   Fix `NumberHelper` raising `FloatDomainError` for `Infinity` / `NaN` with
    `significant: true`.

    `number_to_rounded(Float::INFINITY, precision: 3, significant: true)` (and
    its callers `number_to_percentage`, `number_to_currency`, etc.) raised
    `FloatDomainError` because `RoundingHelper#digit_count` called
    `Math.log10(Float::INFINITY).floor`. The non-`significant` path already
    formatted these values as `"Inf"` / `"-Inf"` / `"NaN"`; the two paths now
    agree.

    *Kenta Ishizaki*

*   Fix `number_to_delimited` mangling non-finite floats.

    `number_to_delimited(Float::INFINITY)` returned `"In,fin,ity"` because the
    fast-path manual slicing introduced in commit `2d485aecf5` and made the
    default in commit `33fbedb1b1` treated `Float::INFINITY.to_s` (the string
    `"Infinity"`) as a sequence of digits to group every three characters.
    `-Float::INFINITY` was similarly mangled to `"-In,fin,ity"`. `Float::NAN`
    happened to survive only because `"NaN"` is exactly three characters long.

    Now returns the underlying string representation (`"Infinity"`,
    `"-Infinity"`, `"NaN"`) for non-finite floats, matching the pre-`2d485aecf5`
    behavior.

    *Kenta Ishizaki*

*   Duplicate the `context` hash passed to `ActiveSupport::ErrorReport#handle` for each subscriber.
    This prevents mutations done on the `context` by one subscriber from effecting the others.

    *Andrew Novoselac*

*   Fix `ActiveSupport::Concurrency::ShareLock` to honor `isolation_level`.

    Lock ownership was keyed on `Thread.current`. Under
    `config.active_support.isolation_level = :fiber`, all request fibers
    on the same thread were treated as a single owner, and the reloader
    interlock could admit an exclusive `:unload` while another fiber
    still held a share — clearing autoloaded constants mid-request.

    `ShareLock` now keys ownership on
    `ActiveSupport::IsolatedExecutionState.context`, the same scope used
    by `CurrentAttributes` and other per-execution state. Behavior under
    `:thread` isolation is unchanged.

    *Joel Junström*

*   Introduce `ActiveSupport::TimeFormats` and `ActiveSupport::DateFormats`
    for registering custom date formats.

    This allows adding custom date formats to `to_fs` without modifying the
    global `Time::DATE_FORMATS` or `Date::DATE_FORMATS` hashes. Custom formats
    are added via `ActiveSupport::TimeFormats.register` or
    `ActiveSupport::DateFormats.register`, and will only be available to
    `Time#to_fs`, and `Date#to_fs` respectively.

    At the same time, the existing `Time::DATE_FORMATS` and `Date::DATE_FORMATS`
    constants are still supported for backward compatibility, but they are now
    deprecated and will be removed in the next version of Rails. This encourages
    users to migrate to the new approach for better encapsulation and to avoid
    potential conflicts with other libraries that may also modify the global
    date formats.

    ```ruby
    ActiveSupport::TimeFormats.register(:month_and_year, '%B %Y')
    ActiveSupport::DateFormats.register(
      :short_ordinal,
      ->(date) { date.strftime("%B #{date.day.ordinalize}") }
    )

    Time.now.to_fs(:month_and_year) # => "February 2024"
    Date.today.to_fs(:short_ordinal)  # => "February 21st"
    ```

    *Ufuk Kayserilioglu*

*   Add `start_day` argument to `this_week?` for consistency with `all_week`

    `this_week?` now accepts an optional `start_day` argument, matching the
    existing interface of `all_week`, `beginning_of_week`, and `end_of_week`.

        date.this_week?              # Uses Date.beginning_of_week (default)
        date.this_week?(:sunday)     # Checks against Sun-Sat week

    *Kenta Ishizaki*

*   Add `delete: true` option to `Rails.cache.read` for atomic read-and-delete (only supported by Redis cache store).

    Uses the Redis [GETDEL](https://redis.io/docs/latest/commands/getdel/) command to atomically return a cached value and remove
    it in a single operation. Useful for single-use values like OTP codes or
    one-time tokens.

    ```ruby
    Rails.cache.write("otp", "123456")
    Rails.cache.read("otp", delete: true)  # => "123456"
    Rails.cache.read("otp")                # => nil
    ```

    *Glauco Custodio*

*   Introduce `ActiveSupport::TestCase.around`

    Add a callback, which runs between `TestCase#setup` and `TestCase#teardown`.
    Yields the test class instance and the test case to the block:

    ```ruby
    class ClientTest < ActiveSupport::TestCase
      around do |test_case, block|
        Client.with(stubbed: true, &block)
      end
    end
    ```

    *Sean Doyle*

*   Add `prepend: true` option to `ActiveSupport::Notifications.subscribe`.

      When `prepend: true` is passed, the subscriber is added to the front of
      the subscriber list for the given event, ensuring it runs before any
      previously registered subscribers. This allows mutating the event payload
      before other subscribers process it.

      ```ruby
      ActiveSupport::Notifications.subscribe("sql.active_record", prepend: true) do |event|
        event.payload[:name] = "[IDC] #{event.payload[:name]}"
      end
      ```

      *Jean Boussier*, *Federico Carrocera*

*   Deprecate `require_dependency`.

    `require_dependency` is deprecated without replacement and will be removed in Rails 9.

    - Recommendations for applications:

        - If the call is an old one written in the days of the classic
          autoloader to ensure a certain constant is loaded for constant lookup
          to work as expected, you can simply remove it.

        - In order to preload classes when the application boots, which may be
          necessary for things like STIs or Kafka consumers, please check the
          autoloading guide for modern approaches.

    - Recommendations for engines that depend on Rails >= 7.0:

      Same recommendations as for applications, since the classic autoloader is
      no longer available starting with Rails 7.0.

    - Recommendations for engines that support Rails < 7.0:

      Guard the call with a version check just in case the parent application is
      using the classic autoloader:

      ```ruby
      require_dependency "some_file" if Rails::VERSION::MAJOR < 7
      ```

    *Xavier Noria*

*   Add `group` method to `ActiveSupport::ContinuousIntegration` for parallel step execution.

    Groups collect steps and run them concurrently using a thread pool, reducing CI times
    by running independent checks in parallel. Sub-groups run sequentially within a single
    parallel slot allowing dependent steps to be grouped together.

    ```ruby
    CI.run do
      step "Setup", "bin/setup --skip-server"

      group "Checks", parallel: 2 do
        step "Style: Ruby", "bin/rubocop"
        step "Security: Brakeman", "bin/brakeman --quiet"
        step "Security: Gem audit", "bin/bundler-audit"

        group "Tests" do
          step "Tests: Rails", "bin/rails test"
          step "Tests: Seeds", "env RAILS_ENV=test bin/rails db:seed:replant"
        end
      end
    end
    ```

    *Donal McBreen*

*   Introduce `this_week?`, `this_month?`, and `this_year?` methods to Date/Time

    Similar to `today?`, `tomorrow?`, and `yesterday?`, these methods are useful to
    query time instances against the current period.

    ```ruby
    unless post.created_at.this_week?
      link_to "See week recap", week_recap_path(date)
    end
    ```

    *Matheus Richard*

*   Removed the deprecated `ActiveSupport::Multibyte::Chars` class.

    As well as `String#mb_chars`

    *Jean Boussier*

*   Changed `ActiveSupport::EventReporter#subscribe` to only provide the event name during filtering.

    Otherwise the event reporter would need to always build the expensive payload even when there is
    no active subscriber, which is very wasteful.

    *Jean Boussier*

*   Fix inflections to better handle overlapping acronyms.

    ```ruby
    ActiveSupport::Inflector.inflections(:en) do |inflect|
      inflect.acronym "USD"
      inflect.acronym "USDC"
    end

    "USDC".underscore # => "usdc"
    ```

    *Said Kaldybaev*

*   Add `ActiveSupport::CombinedConfiguration` to offer interchangeable access to configuration provided by
    either ENV or encrypted credentials. Used by Rails to first look at ENV, then look in encrypted credentials,
    but can be configured separately with any number of API-compatible backends in a first-look order.

    The object is inspect safe and will only show keys, not values.

    *DHH*, *Emmanuel Hayford*

*   Add `ActiveSupport::EnvConfiguration` to provide access to ENV variables in a way that's compatible with
    `ActiveSupport::EncryptedConfiguration` and therefore can be used by `ActiveSupport::CombinedConfiguration`.

    The object is inspect safe and will only show keys, not values.

    Examples:

    ```ruby
    conf = ActiveSupport::EnvConfiguration.new
    conf.require(:db_host) # ENV.fetch("DB_HOST")
    conf.require(:aws, :access_key_id) # ENV.fetch("AWS__ACCESS_KEY_ID")
    conf.option(:cache_host) # ENV["CACHE_HOST"]
    conf.option(:cache_host, default: "cache-host-1") # ENV["CACHE_HOST"] || "cache-host-1"
    conf.option(:cache_host, default: -> { "cache-host-1" }) # ENV["CACHE_HOST"] || "cache-host-1"
    ```

    *DHH*, *Emmanuel Hayford*

*   Make flaky parallel tests easier to diagnose by deterministically assigning
    tests to workers.

    Rails assigns tests to workers in round-robin order so the same `--seed`
    and worker count will result in the same sequence of tests running on each
    worker (whether processes or threads) increasing the odds of reproducing
    test failures caused by test interdependence.

    This can make test runtime slower and spikier when one worker gets most of
    the slow tests. Enable `work_stealing: true` to allow idle workers to steal
    tests from busy workers in deterministic order, smoothing out runtime at the
    cost of less reproducible flaky-test failures.

    *Jeremy Daer*

*   Make `ActiveSupport::EventReporter#debug_mode?` true by default to emit debug events
    outside of Rails application contexts.

    *Gannon McGibbon*

*   Add `SecureRandom.base32` for generating case-insensitive keys that are unambiguous to humans.

    *Stanko Krtalic Rusendic & Miha Rekar*

*   Add a fast failure mode to `ActiveSupport::ContinuousIntegration` that stops the rest of
    the run after a step fails. Invoke by running `bin/ci --fail-fast` or `bin/ci -f`.

    *Dennis Paagman*

*   Implement LocalCache strategy on `ActiveSupport::Cache::MemoryStore`. The memory store
    needs to respond to the same interface as other cache stores (e.g. `ActiveSupport::NullStore`).

    *Mikey Gough*

*   Add a detailed failure summary to `ActiveSupport::ContinuousIntegration`.

    *Mike Dalessio*

*   Introduce `ActiveSupport::EventReporter::LogSubscriber` structured event logging.

    ```ruby
    class MyLogSubscriber < ActiveSupport::EventReporter::LogSubscriber
      self.namespace = "test"

      def something(event)
        info { "Event #{event[:name]} emitted." }
      end
    end
    ```

    *Gannon McGibbon*


Please check [8-1-stable](https://github.com/rails/rails/blob/8-1-stable/activesupport/CHANGELOG.md) for previous changes.
