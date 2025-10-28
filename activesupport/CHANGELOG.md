## Rails 8.1.1 (October 28, 2025) ##

*   No changes.


## Rails 8.1.0 (October 22, 2025) ##

*   Remove deprecated passing a Time object to `Time#since`.

    *Rafael Mendonça França*

*   Remove deprecated `Benchmark.ms` method. It is now defined in the `benchmark` gem.

    *Rafael Mendonça França*

*   Remove deprecated addition for `Time` instances with `ActiveSupport::TimeWithZone`.

    *Rafael Mendonça França*

*   Remove deprecated support for `to_time` to preserve the system local time. It will now always preserve the receiver
    timezone.

    *Rafael Mendonça França*

*   Deprecate `config.active_support.to_time_preserves_timezone`.

    *Rafael Mendonça França*

*   Standardize event name formatting in `assert_event_reported` error messages.

    The event name in failure messages now uses `.inspect` (e.g., `name: "user.created"`)
    to match `assert_events_reported` and provide type clarity between strings and symbols.
    This only affects tests that assert on the failure message format itself.

    *George Ma*

*   Fix `Enumerable#sole` to return the full tuple instead of just the first element of the tuple.

    *Olivier Bellone*

*   Fix parallel tests hanging when worker processes die abruptly.

    Previously, if a worker process was killed (e.g., OOM killed, `kill -9`) during parallel
    test execution, the test suite would hang forever waiting for the dead worker.

    *Joshua Young*

*   Add `config.active_support.escape_js_separators_in_json`.

    Introduce a new framework default to skip escaping LINE SEPARATOR (U+2028) and PARAGRAPH SEPARATOR (U+2029) in JSON.

    Historically these characters were not valid inside JavaScript literal strings but that changed in ECMAScript 2019.
    As such it's no longer a concern in modern browsers: https://caniuse.com/mdn-javascript_builtins_json_json_superset.

    *Étienne Barrié*, *Jean Boussier*

*   Fix `NameError` when `class_attribute` is defined on instance singleton classes.

    Previously, calling `class_attribute` on an instance's singleton class would raise
    a `NameError` when accessing the attribute through the instance.

    ```ruby
    object = MyClass.new
    object.singleton_class.class_attribute :foo, default: "bar"
    object.foo # previously raised NameError, now returns "bar"
    ```

    *Joshua Young*

*   Introduce `ActiveSupport::Testing::EventReporterAssertions#with_debug_event_reporting`
    to enable event reporter debug mode in tests.

    The previous way to enable debug mode is by using `#with_debug` on the
    event reporter itself, which is too verbose. This new helper will help
    clear up any confusion on how to test debug events.

    *Gannon McGibbon*

*   Add `ActiveSupport::StructuredEventSubscriber` for consuming notifications and
    emitting structured event logs. Events may be emitted with the `#emit_event`
    or `#emit_debug_event` methods.

    ```ruby
    class MyStructuredEventSubscriber < ActiveSupport::StructuredEventSubscriber
      def notification(event)
        emit_event("my.notification", data: 1)
      end
    end
    ```

    *Adrianna Chang*

*   `ActiveSupport::FileUpdateChecker` does not depend on `Time.now` to prevent unecessary reloads with time travel test helpers

    *Jan Grodowski*

*   Add `ActiveSupport::Cache::Store#namespace=` and `#namespace`.

    Can be used as an alternative to `Store#clear` in some situations such as parallel
    testing.

    *Nick Schwaderer*

*   Create `parallel_worker_id` helper for running parallel tests. This allows users to
    know which worker they are currently running in.

    *Nick Schwaderer*

*   Make the cache of `ActiveSupport::Cache::Strategy::LocalCache::Middleware` updatable.

    If the cache client at `Rails.cache` of a booted application changes, the corresponding
    mounted middleware needs to update in order for request-local caches to be setup properly.
    Otherwise, redundant cache operations will erroneously hit the datastore.

    *Gannon McGibbon*

*   Add `assert_events_reported` test helper for `ActiveSupport::EventReporter`.

    This new assertion allows testing multiple events in a single block, regardless of order:

    ```ruby
    assert_events_reported([
      { name: "user.created", payload: { id: 123 } },
      { name: "email.sent", payload: { to: "user@example.com" } }
    ]) do
      create_user_and_send_welcome_email
    end
    ```

    *George Ma*

*   Add `ActiveSupport::TimeZone#standard_name` method.

    ``` ruby
    zone = ActiveSupport::TimeZone['Hawaii']
    # Old way
    ActiveSupport::TimeZone::MAPPING[zone.name]
    # New way
    zone.standard_name # => 'Pacific/Honolulu'
    ```

    *Bogdan Gusiev*

*   Add Structured Event Reporter, accessible via `Rails.event`.

    The Event Reporter provides a unified interface for producing structured events in Rails
    applications:

    ```ruby
    Rails.event.notify("user.signup", user_id: 123, email: "user@example.com")
    ```

    It supports adding tags to events:

    ```ruby
    Rails.event.tagged("graphql") do
      # Event includes tags: { graphql: true }
      Rails.event.notify("user.signup", user_id: 123, email: "user@example.com")
    end
    ```

    As well as context:
    ```ruby
    # All events will contain context: {request_id: "abc123", shop_id: 456}
    Rails.event.set_context(request_id: "abc123", shop_id: 456)
    ```

    Events are emitted to subscribers. Applications register subscribers to
    control how events are serialized and emitted. Subscribers must implement
    an `#emit` method, which receives the event hash:

    ```ruby
    class LogSubscriber
      def emit(event)
        payload = event[:payload].map { |key, value| "#{key}=#{value}" }.join(" ")
        source_location = event[:source_location]
        log = "[#{event[:name]}] #{payload} at #{source_location[:filepath]}:#{source_location[:lineno]}"
        Rails.logger.info(log)
      end
    end
    ```

    *Adrianna Chang*

*   Make `ActiveSupport::Logger` `#freeze`-friendly.

    *Joshua Young*

*   Make `ActiveSupport::Gzip.compress` deterministic based on input.

    `ActiveSupport::Gzip.compress` used to include a timestamp in the output,
    causing consecutive calls with the same input data to have different output
    if called during different seconds. It now always sets the timestamp to `0`
    so that the output is identical for any given input.

    *Rob Brackett*

*   Given an array of `Thread::Backtrace::Location` objects, the new method
    `ActiveSupport::BacktraceCleaner#clean_locations` returns an array with the
    clean ones:

    ```ruby
    clean_locations = backtrace_cleaner.clean_locations(caller_locations)
    ```

    Filters and silencers receive strings as usual. However, the `path`
    attributes of the locations in the returned array are the original,
    unfiltered ones, since locations are immutable.

    *Xavier Noria*

*   Improve `CurrentAttributes` and `ExecutionContext` state managment in test cases.

    Previously these two global state would be entirely cleared out whenever calling
    into code that is wrapped by the Rails executor, typically Action Controller or
    Active Job helpers:

    ```ruby
    test "#index works" do
      CurrentUser.id = 42
      get :index
      CurrentUser.id == nil
    end
    ```

    Now re-entering the executor properly save and restore that state.

    *Jean Boussier*

*   The new method `ActiveSupport::BacktraceCleaner#first_clean_location`
    returns the first clean location of the caller's call stack, or `nil`.
    Locations are `Thread::Backtrace::Location` objects. Useful when you want to
    report the application-level location where something happened as an object.

    *Xavier Noria*

*   FileUpdateChecker and EventedFileUpdateChecker ignore changes in Gem.path now.

    *Ermolaev Andrey*, *zzak*

*   The new method `ActiveSupport::BacktraceCleaner#first_clean_frame` returns
    the first clean frame of the caller's backtrace, or `nil`. Useful when you
    want to report the application-level frame where something happened as a
    string.

    *Xavier Noria*

*   Always clear `CurrentAttributes` instances.

    Previously `CurrentAttributes` instance would be reset at the end of requests.
    Meaning its attributes would be re-initialized.

    This is problematic because it assume these objects don't hold any state
    other than their declared attribute, which isn't always the case, and
    can lead to state leak across request.

    Now `CurrentAttributes` instances are abandoned at the end of a request,
    and a new instance is created at the start of the next request.

    *Jean Boussier*, *Janko Marohnić*

*   Add public API for `before_fork_hook` in parallel testing.

    Introduces a public API for calling the before fork hooks implemented by parallel testing.

    ```ruby
    parallelize_before_fork do
        # perform an action before test processes are forked
    end
    ```

    *Eileen M. Uchitelle*

*   Implement ability to skip creating parallel testing databases.

    With parallel testing, Rails will create a database per process. If this isn't
    desirable or you would like to implement databases handling on your own, you can
    now turn off this default behavior.

    To skip creating a database per process, you can change it via the
    `parallelize` method:

    ```ruby
    parallelize(workers: 10, parallelize_databases: false)
    ```

    or via the application configuration:

    ```ruby
    config.active_support.parallelize_databases = false
    ```

    *Eileen M. Uchitelle*

*   Allow to configure maximum cache key sizes

    When the key exceeds the configured limit (250 bytes by default), it will be truncated and
    the digest of the rest of the key appended to it.

    Note that previously `ActiveSupport::Cache::RedisCacheStore` allowed up to 1kb cache keys before
    truncation, which is now reduced to 250 bytes.

    ```ruby
    config.cache_store = :redis_cache_store, { max_key_size: 64 }
    ```

    *fatkodima*

*   Use `UNLINK` command instead of `DEL` in `ActiveSupport::Cache::RedisCacheStore` for non-blocking deletion.

    *Aron Roh*

*   Add `Cache#read_counter` and `Cache#write_counter`

    ```ruby
    Rails.cache.write_counter("foo", 1)
    Rails.cache.read_counter("foo") # => 1
    Rails.cache.increment("foo")
    Rails.cache.read_counter("foo") # => 2
    ```

    *Alex Ghiculescu*

*   Introduce ActiveSupport::Testing::ErrorReporterAssertions#capture_error_reports

    Captures all reported errors from within the block that match the given
    error class.

    ```ruby
    reports = capture_error_reports(IOError) do
      Rails.error.report(IOError.new("Oops"))
      Rails.error.report(IOError.new("Oh no"))
      Rails.error.report(StandardError.new)
    end

    assert_equal 2, reports.size
    assert_equal "Oops", reports.first.error.message
    assert_equal "Oh no", reports.last.error.message
    ```

    *Andrew Novoselac*

*   Introduce ActiveSupport::ErrorReporter#add_middleware

    When reporting an error, the error context middleware will be called with the reported error
    and base execution context. The stack may mutate the context hash. The mutated context will
    then be passed to error subscribers. Middleware receives the same parameters as `ErrorReporter#report`.

    *Andrew Novoselac*, *Sam Schmidt*

*   Change execution wrapping to report all exceptions, including `Exception`.

    If a more serious error like `SystemStackError` or `NoMemoryError` happens,
    the error reporter should be able to report these kinds of exceptions.

    *Gannon McGibbon*

*   `ActiveSupport::Testing::Parallelization.before_fork_hook` allows declaration of callbacks that
    are invoked immediately before forking test workers.

    *Mike Dalessio*

*   Allow the `#freeze_time` testing helper to accept a date or time argument.

    ```ruby
    Time.current # => Sun, 09 Jul 2024 15:34:49 EST -05:00
    freeze_time Time.current + 1.day
    sleep 1
    Time.current # => Mon, 10 Jul 2024 15:34:49 EST -05:00
    ```

    *Joshua Young*

*   `ActiveSupport::JSON` now accepts options

    It is now possible to pass options to `ActiveSupport::JSON`:
    ```ruby
    ActiveSupport::JSON.decode('{"key": "value"}', symbolize_names: true) # => { key: "value" }
    ```

    *matthaigh27*

*   `ActiveSupport::Testing::NotificationAssertions`'s `assert_notification` now matches against payload subsets by default.

    Previously the following assertion would fail due to excess key vals in the notification payload. Now with payload subset matching, it will pass.

    ```ruby
    assert_notification("post.submitted", title: "Cool Post") do
      ActiveSupport::Notifications.instrument("post.submitted", title: "Cool Post", body: "Cool Body")
    end
    ```

    Additionally, you can now persist a matched notification for more customized assertions.

    ```ruby
    notification = assert_notification("post.submitted", title: "Cool Post") do
      ActiveSupport::Notifications.instrument("post.submitted", title: "Cool Post", body: Body.new("Cool Body"))
    end

    assert_instance_of(Body, notification.payload[:body])
    ```

    *Nicholas La Roux*

*   Deprecate `String#mb_chars` and `ActiveSupport::Multibyte::Chars`.

    These APIs are a relic of the Ruby 1.8 days when Ruby strings weren't encoding
    aware. There is no legitimate reasons to need these APIs today.

    *Jean Boussier*

*   Deprecate `ActiveSupport::Configurable`

    *Sean Doyle*

*   `nil.to_query("key")` now returns `key`.

    Previously it would return `key=`, preventing round tripping with `Rack::Utils.parse_nested_query`.

    *Erol Fornoles*

*   Avoid wrapping redis in a `ConnectionPool` when using `ActiveSupport::Cache::RedisCacheStore` if the `:redis`
    option is already a `ConnectionPool`.

    *Joshua Young*

*   Alter `ERB::Util.tokenize` to return :PLAIN token with full input string when string doesn't contain ERB tags.

    *Martin Emde*

*   Fix a bug in `ERB::Util.tokenize` that causes incorrect tokenization when ERB tags are preceded by multibyte characters.

    *Martin Emde*

*   Add `ActiveSupport::Testing::NotificationAssertions` module to help with testing `ActiveSupport::Notifications`.

    *Nicholas La Roux*, *Yishu See*, *Sean Doyle*

*   `ActiveSupport::CurrentAttributes#attributes` now will return a new hash object on each call.

    Previously, the same hash object was returned each time that method was called.

    *fatkodima*

*   `ActiveSupport::JSON.encode` supports CIDR notation.

    Previously:

    ```ruby
    ActiveSupport::JSON.encode(IPAddr.new("172.16.0.0/24")) # => "\"172.16.0.0\""
    ```

    After this change:

    ```ruby
    ActiveSupport::JSON.encode(IPAddr.new("172.16.0.0/24")) # => "\"172.16.0.0/24\""
    ```

    *Taketo Takashima*

*   Make `ActiveSupport::FileUpdateChecker` faster when checking many file-extensions.

    *Jonathan del Strother*

Please check [8-0-stable](https://github.com/rails/rails/blob/8-0-stable/activesupport/CHANGELOG.md) for previous changes.
