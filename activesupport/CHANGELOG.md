## Rails 7.1.3.2 (February 21, 2024) ##

*   No changes.


## Rails 7.1.3.1 (February 21, 2024) ##

*   No changes.


## Rails 7.1.3 (January 16, 2024) ##

*   Handle nil `backtrace_locations` in `ActiveSupport::SyntaxErrorProxy`.

    *Eugene Kenny*

*   Fix `ActiveSupport::JSON.encode` to prevent duplicate keys.

    If the same key exist in both String and Symbol form it could
    lead to the same key being emitted twice.

    *Manish Sharma*

*   Fix `ActiveSupport::Cache::Store#read_multi` when using a cache namespace
    and local cache strategy.

    *Mark Oleson*

*   Fix `Time.now/DateTime.now/Date.today` to return results in a system timezone after `#travel_to`.

    There is a bug in the current implementation of #travel_to:
    it remembers a timezone of its argument, and all stubbed methods start
    returning results in that remembered timezone. However, the expected
    behaviour is to return results in a system timezone.

    *Aleksei Chernenkov*

*   Fix `:unless_exist` option for `MemoryStore#write` (et al) when using a
    cache namespace.

    *S. Brent Faulkner*

*   Fix ActiveSupport::Deprecation to handle blaming generated code.

    *Jean Boussier*, *fatkodima*


## Rails 7.1.2 (November 10, 2023) ##

*   Fix `:expires_in` option for `RedisCacheStore#write_multi`.

    *fatkodima*

*   Fix deserialization of non-string "purpose" field in Message serializer

    *Jacopo Beschi*

*   Prevent global cache options being overwritten when setting dynamic options
    inside a `ActiveSupport::Cache::Store#fetch` block.

    *Yasha Krasnou*

*   Fix missing `require` resulting in `NoMethodError` when running
    `bin/rails secrets:show` or `bin/rails secrets:edit`.

    *Stephen Ierodiaconou*

*   Ensure `{down,up}case_first` returns non-frozen string.

    *Jonathan Hefner*

*   Fix `#to_fs(:human_size)` to correctly work with negative numbers.

    *Earlopain*

*   Fix `BroadcastLogger#dup` so that it duplicates the logger's `broadcasts`.

    *Andrew Novoselac*

*   Fix issue where `bootstrap.rb` overwrites the `level` of a `BroadcastLogger`'s `broadcasts`.

    *Andrew Novoselac*

*   Fix `ActiveSupport::Cache` to handle outdated Marshal payload from Rails 6.1 format.

    Active Support's Cache is supposed to treat a Marshal payload that can no longer be
    deserialized as a cache miss. It fail to do so for compressed payload in the Rails 6.1
    legacy format.

    *Jean Boussier*

*   Fix `OrderedOptions#dig` for array indexes.

    *fatkodima*

*   Fix time travel helpers to work when nested using with separate classes.

    *fatkodima*

*   Fix `delete_matched` for file cache store to work with keys longer than the
    max filename size.

    *fatkodima* and *Jonathan Hefner*

*   Fix compatibility with the `semantic_logger` gem.

    The `semantic_logger` gem doesn't behave exactly like stdlib logger in that
    `SemanticLogger#level` returns a Symbol while stdlib `Logger#level` returns an Integer.

    This caused the various `LogSubscriber` classes in Rails to break when assigned a
    `SemanticLogger` instance.

    *Jean Boussier*, *ojab*

## Rails 7.1.1 (October 11, 2023) ##

*   Add support for keyword arguments when delegating calls to custom loggers from `ActiveSupport::BroadcastLogger`.

    *Edouard Chin*

*   `NumberHelper`: handle objects responding `to_d`.

    *fatkodima*

*   Fix RedisCacheStore to properly set the TTL when incrementing or decrementing.

    This bug was only impacting Redis server older than 7.0.

    *Thomas Countz*

*   Fix MemoryStore to prevent race conditions when incrementing or decrementing.

    *Pierre Jambet*


## Rails 7.1.0 (October 05, 2023) ##

*   No changes.


## Rails 7.1.0.rc2 (October 01, 2023) ##

*   Fix `AS::MessagePack` with `ENV["RAILS_MAX_THREADS"]`.

    *Jonathan Hefner*


## Rails 7.1.0.rc1 (September 27, 2023) ##

*   Add a new public API for broadcasting logs

    This feature existed for a while but was until now a private API.
    Broadcasting log allows to send log message to difference sinks (STDOUT, a file ...) and
    is used by default in the development environment to write logs both on STDOUT and in the
    "development.log" file.

    Basic usage:

    ```ruby
    stdout_logger = Logger.new(STDOUT)
    file_logger = Logger.new("development.log")
    broadcast = ActiveSupport::BroadcastLogger.new(stdout_logger, file_logger)

    broadcast.info("Hello!") # The "Hello!" message is written on STDOUT and in the log file.
    ```

    Adding other sink(s) to the broadcast:

    ```ruby
    broadcast = ActiveSupport::BroadcastLogger.new
    broadcast.broadcast_to(Logger.new(STDERR))
    ```

    Remove a sink from the broadcast:

    ```ruby
    stdout_logger = Logger.new(STDOUT)
    broadcast = ActiveSupport::BroadcastLogger.new(stdout_logger)

    broadcast.stop_broadcasting_to(stdout_logger)
    ```

    *Edouard Chin*

*   Fix Range#overlap? not taking empty ranges into account on Ruby < 3.3

    *Nobuyoshi Nakada*, *Shouichi Kamiya*, *Hartley McGuire*

*   Use Ruby 3.3 Range#overlap? if available

    *Yasuo Honda*


## Rails 7.1.0.beta1 (September 13, 2023) ##

*   Add `bigdecimal` as Active Support dependency that is a bundled gem candidate for Ruby 3.4.

    `bigdecimal` 3.1.4 or higher version will be installed.
    Ruby 2.7 and 3.0 users who want `bigdecimal` version 2.0.0 or 3.0.0 behavior as a default gem,
    pin the `bigdecimal` version in your application Gemfile.

    *Koichi ITO*

*   Add `drb`, `mutex_m` and `base64` that are bundled gem candidates for Ruby 3.4

    *Yasuo Honda*

*   When using cache format version >= 7.1 or a custom serializer, expired and
    version-mismatched cache entries can now be detected without deserializing
    their values.

    *Jonathan Hefner*

*   Make all cache stores return a boolean for `#delete`

    Previously the `RedisCacheStore#delete` would return `1` if the entry
    exists and `0` otherwise. Now it returns true if the entry exists and false
    otherwise, just like the other stores.

    The `FileStore` would return `nil` if the entry doesn't exists and returns
    `false` now as well.

    *Petrik de Heus*

*   Active Support cache stores now support replacing the default compressor via
    a `:compressor` option. The specified compressor must respond to `deflate`
    and `inflate`. For example:

      ```ruby
      module MyCompressor
        def self.deflate(string)
          # compression logic...
        end

        def self.inflate(compressed)
          # decompression logic...
        end
      end

      config.cache_store = :redis_cache_store, { compressor: MyCompressor }
      ```

    *Jonathan Hefner*

*   Active Support cache stores now support a `:serializer` option. Similar to
    the `:coder` option, serializers must respond to `dump` and `load`. However,
    serializers are only responsible for serializing a cached value, whereas
    coders are responsible for serializing the entire `ActiveSupport::Cache::Entry`
    instance.  Additionally, the output from serializers can be automatically
    compressed, whereas coders are responsible for their own compression.

    Specifying a serializer instead of a coder also enables performance
    optimizations, including the bare string optimization introduced by cache
    format version 7.1.

    The `:serializer` and `:coder` options are mutually exclusive. Specifying
    both will raise an `ArgumentError`.

    *Jonathan Hefner*

*   Fix `ActiveSupport::Inflector.humanize(nil)` raising ``NoMethodError: undefined method `end_with?' for nil:NilClass``.

    *James Robinson*

*   Don't show secrets for `ActiveSupport::KeyGenerator#inspect`.

    Before:

    ```ruby
    ActiveSupport::KeyGenerator.new(secret).inspect
    "#<ActiveSupport::KeyGenerator:0x0000000104888038 ... @secret=\"\\xAF\\bFh]LV}q\\nl\\xB2U\\xB3 ... >"
    ```

    After:

    ```ruby
    ActiveSupport::KeyGenerator::Aes256Gcm(secret).inspect
    "#<ActiveSupport::KeyGenerator:0x0000000104888038>"
    ```

    *Petrik de Heus*

*   Improve error message when EventedFileUpdateChecker is used without a
    compatible version of the Listen gem

    *Hartley McGuire*

*   Add `:report` behavior for Deprecation

    Setting `config.active_support.deprecation = :report` uses the error
    reporter to report deprecation warnings to `ActiveSupport::ErrorReporter`.

    Deprecations are reported as handled errors, with a severity of `:warning`.

    Useful to report deprecations happening in production to your bug tracker.

    *Étienne Barrié*

*   Rename `Range#overlaps?` to `#overlap?` and add alias for backwards compatibility

    *Christian Schmidt*

*   Fix `EncryptedConfiguration` returning incorrect values for some `Hash`
    methods

    *Hartley McGuire*

*   Don't show secrets for `MessageEncryptor#inspect`.

    Before:

    ```ruby
    ActiveSupport::MessageEncryptor.new(secret, cipher: "aes-256-gcm").inspect
    "#<ActiveSupport::MessageEncryptor:0x0000000104888038 ... @secret=\"\\xAF\\bFh]LV}q\\nl\\xB2U\\xB3 ... >"
    ```

    After:

    ```ruby
    ActiveSupport::MessageEncryptor.new(secret, cipher: "aes-256-gcm").inspect
    "#<ActiveSupport::MessageEncryptor:0x0000000104888038>"
    ```

    *Petrik de Heus*

*   Don't show contents for `EncryptedConfiguration#inspect`.

    Before:
    ```ruby
    Rails.application.credentials.inspect
    "#<ActiveSupport::EncryptedConfiguration:0x000000010d2b38e8 ... @config={:secret=>\"something secret\"} ... @key_file_contents=\"915e4ea054e011022398dc242\" ...>"
    ```

    After:
    ```ruby
    Rails.application.credentials.inspect
    "#<ActiveSupport::EncryptedConfiguration:0x000000010d2b38e8>"
    ```

    *Petrik de Heus*

*   `ERB::Util.html_escape_once` always returns an `html_safe` string.

    This method previously maintained the `html_safe?` property of a string on the return
    value. Because this string has been escaped, however, not marking it as `html_safe` causes
    entities to be double-escaped.

    As an example, take this view snippet:

      ```html
      <p><%= html_escape_once("this & that &amp; the other") %></p>
      ```

    Before this change, that would be double-escaped and render as:

      ```html
      <p>this &amp;amp; that &amp;amp; the other</p>
      ```

    After this change, it renders correctly as:

      ```html
      <p>this &amp; that &amp; the other</p>
      ```

    Fixes #48256

    *Mike Dalessio*

*   Deprecate `SafeBuffer#clone_empty`.

    This method has not been used internally since Rails 4.2.0.

    *Mike Dalessio*

*   `MessageEncryptor`, `MessageVerifier`, and `config.active_support.message_serializer`
    now accept `:message_pack` and `:message_pack_allow_marshal` as serializers.
    These serializers require the [`msgpack` gem](https://rubygems.org/gems/msgpack)
    (>= 1.7.0).

    The Message Pack format can provide improved performance and smaller payload
    sizes. It also supports round-tripping some Ruby types that are not supported
    by JSON. For example:

      ```ruby
      verifier = ActiveSupport::MessageVerifier.new("secret")
      data = [{ a: 1 }, { b: 2 }.with_indifferent_access, 1.to_d, Time.at(0, 123)]
      message = verifier.generate(data)

      # BEFORE with config.active_support.message_serializer = :json
      verifier.verified(message)
      # => [{"a"=>1}, {"b"=>2}, "1.0", "1969-12-31T18:00:00.000-06:00"]
      verifier.verified(message).map(&:class)
      # => [Hash, Hash, String, String]

      # AFTER with config.active_support.message_serializer = :message_pack
      verifier.verified(message)
      # => [{:a=>1}, {"b"=>2}, 0.1e1, 1969-12-31 18:00:00.000123 -0600]
      verifier.verified(message).map(&:class)
      # => [Hash, ActiveSupport::HashWithIndifferentAccess, BigDecimal, Time]
      ```

    The `:message_pack` serializer can fall back to deserializing with
    `ActiveSupport::JSON` when necessary, and the `:message_pack_allow_marshal`
    serializer can fall back to deserializing with `Marshal` as well as
    `ActiveSupport::JSON`. Additionally, the `:marshal`, `:json`, and
    `:json_allow_marshal` serializers can now fall back to deserializing with
    `ActiveSupport::MessagePack` when necessary. These behaviors ensure old
    messages can still be read so that migration is easier.

    *Jonathan Hefner*

*   A new `7.1` cache format is available which includes an optimization for
    bare string values such as view fragments.

    The `7.1` cache format is used by default for new apps, and existing apps
    can enable the format by setting `config.load_defaults 7.1` or by setting
    `config.active_support.cache_format_version = 7.1` in `config/application.rb`
    or a `config/environments/*.rb` file.

    Cache entries written using the `6.1` or `7.0` cache formats can be read
    when using the `7.1` format. To perform a rolling deploy of a Rails 7.1
    upgrade, wherein servers that have not yet been upgraded must be able to
    read caches from upgraded servers, leave the cache format unchanged on the
    first deploy, then enable the `7.1` cache format on a subsequent deploy.

    *Jonathan Hefner*

*   Active Support cache stores can now use a preconfigured serializer based on
    `ActiveSupport::MessagePack` via the `:serializer` option:

      ```ruby
      config.cache_store = :redis_cache_store, { serializer: :message_pack }
      ```

    The `:message_pack` serializer can reduce cache entry sizes and improve
    performance, but requires the [`msgpack` gem](https://rubygems.org/gems/msgpack)
    (>= 1.7.0).

    The `:message_pack` serializer can read cache entries written by the default
    serializer, and the default serializer can now read entries written by the
    `:message_pack` serializer. These behaviors make it easy to migrate between
    serializer without invalidating the entire cache.

    *Jonathan Hefner*

*   `Object#deep_dup` no longer duplicate named classes and modules.

    Before:

    ```ruby
    hash = { class: Object, module: Kernel }
    hash.deep_dup # => {:class=>#<Class:0x00000001063ffc80>, :module=>#<Module:0x00000001063ffa00>}
    ```

    After:

    ```ruby
    hash = { class: Object, module: Kernel }
    hash.deep_dup # => {:class=>Object, :module=>Kernel}
    ```

    *Jean Boussier*

*   Consistently raise an `ArgumentError` if the `ActiveSupport::Cache` key is blank.

    *Joshua Young*

*   Deprecate usage of the singleton `ActiveSupport::Deprecation`.

    All usage of `ActiveSupport::Deprecation` as a singleton is deprecated, the most common one being
    `ActiveSupport::Deprecation.warn`. Gem authors should now create their own deprecator (`ActiveSupport::Deprecation`
    object), and use it to emit deprecation warnings.

    Calling any of the following without specifying a deprecator argument is also deprecated:
      * Module.deprecate
      * deprecate_constant
      * DeprecatedObjectProxy
      * DeprecatedInstanceVariableProxy
      * DeprecatedConstantProxy
      * deprecation-related test assertions

    Use of `ActiveSupport::Deprecation.silence` and configuration methods like `behavior=`, `disallowed_behavior=`,
    `disallowed_warnings=` should now be aimed at the [application's deprecators](https://api.rubyonrails.org/classes/Rails/Application.html#method-i-deprecators).

    ```ruby
    Rails.application.deprecators.silence do
      # code that emits deprecation warnings
    end
    ```

    If your gem has a Railtie or Engine, it's encouraged to add your deprecator to the application's deprecators, that
    way the deprecation related configuration options will apply to it as well, e.g.
    `config.active_support.report_deprecations` set to `false` in the production environment will also disable your
    deprecator.

    ```ruby
    initializer "my_gem.deprecator" do |app|
      app.deprecators[:my_gem] = MyGem.deprecator
    end
    ```

    *Étienne Barrié*

*   Add `Object#with` to set and restore public attributes around a block

    ```ruby
    client.timeout # => 5
    client.with(timeout: 1) do
      client.timeout # => 1
    end
    client.timeout # => 5
    ```

    *Jean Boussier*

*   Remove deprecated support to generate incorrect RFC 4122 UUIDs when providing a namespace ID that is not one of the
    constants defined on `Digest::UUID`.

    *Rafael Mendonça França*

*   Deprecate `config.active_support.use_rfc4122_namespaced_uuids`.

    *Rafael Mendonça França*

*   Remove implicit conversion of objects into `String` by `ActiveSupport::SafeBuffer`.

    *Rafael Mendonça França*

*   Remove deprecated `active_support/core_ext/range/include_time_with_zone` file.

    *Rafael Mendonça França*

*   Deprecate `config.active_support.remove_deprecated_time_with_zone_name`.

    *Rafael Mendonça França*

*   Remove deprecated override of `ActiveSupport::TimeWithZone.name`.

    *Rafael Mendonça França*

*   Deprecate `config.active_support.disable_to_s_conversion`.

    *Rafael Mendonça França*

*   Remove deprecated option to passing a format to `#to_s` in `Array`, `Range`, `Date`, `DateTime`, `Time`,
    `BigDecimal`, `Float` and, `Integer`.

    *Rafael Mendonça França*

*   Remove deprecated `ActiveSupport::PerThreadRegistry`.

    *Rafael Mendonça França*

*   Remove deprecated override of `Enumerable#sum`.

    *Rafael Mendonça França*

*   Deprecated initializing a `ActiveSupport::Cache::MemCacheStore` with an instance of `Dalli::Client`.

    Deprecate the undocumented option of providing an already-initialized instance of `Dalli::Client` to `ActiveSupport::Cache::MemCacheStore`. Such clients could be configured with unrecognized options, which could lead to unexpected behavior. Instead, provide addresses as documented.

    *aledustet*

*   Stub `Time.new()` in `TimeHelpers#travel_to`

      ```ruby
      travel_to Time.new(2004, 11, 24) do
        # Inside the `travel_to` block `Time.new` is stubbed
        assert_equal 2004, Time.new.year
      end
      ```

    *fatkodima*

*   Raise `ActiveSupport::MessageEncryptor::InvalidMessage` from
    `ActiveSupport::MessageEncryptor#decrypt_and_verify` regardless of cipher.
    Previously, when a `MessageEncryptor` was using a non-AEAD cipher such as
    AES-256-CBC, a corrupt or tampered message would raise
    `ActiveSupport::MessageVerifier::InvalidSignature`.  Now, all ciphers raise
    the same error:

      ```ruby
      encryptor = ActiveSupport::MessageEncryptor.new("x" * 32, cipher: "aes-256-gcm")
      message = encryptor.encrypt_and_sign("message")
      encryptor.decrypt_and_verify(message.next)
      # => raises ActiveSupport::MessageEncryptor::InvalidMessage

      encryptor = ActiveSupport::MessageEncryptor.new("x" * 32, cipher: "aes-256-cbc")
      message = encryptor.encrypt_and_sign("message")
      encryptor.decrypt_and_verify(message.next)
      # BEFORE:
      # => raises ActiveSupport::MessageVerifier::InvalidSignature
      # AFTER:
      # => raises ActiveSupport::MessageEncryptor::InvalidMessage
      ```

    *Jonathan Hefner*

*   Support `nil` original values when using `ActiveSupport::MessageVerifier#verify`.
    Previously, `MessageVerifier#verify` did not work with `nil` original
    values, though both `MessageVerifier#verified` and
    `MessageEncryptor#decrypt_and_verify` do:

      ```ruby
      encryptor = ActiveSupport::MessageEncryptor.new(secret)
      message = encryptor.encrypt_and_sign(nil)

      encryptor.decrypt_and_verify(message)
      # => nil

      verifier = ActiveSupport::MessageVerifier.new(secret)
      message = verifier.generate(nil)

      verifier.verified(message)
      # => nil

      verifier.verify(message)
      # BEFORE:
      # => raises ActiveSupport::MessageVerifier::InvalidSignature
      # AFTER:
      # => nil
      ```

    *Jonathan Hefner*

*   Maintain `html_safe?` on html_safe strings when sliced with `slice`, `slice!`, or `chr` method.

    Previously, `html_safe?` was only maintained when the html_safe strings were sliced
    with `[]` method. Now, `slice`, `slice!`, and `chr` methods will maintain `html_safe?` like `[]` method.

    ```ruby
    string = "<div>test</div>".html_safe
    string.slice(0, 1).html_safe? # => true
    string.slice!(0, 1).html_safe? # => true
    # maintain html_safe? after the slice!
    string.html_safe? # => true
    string.chr.html_safe? # => true
    ```

    *Michael Go*

*   Add `Object#in?` support for open ranges.

    ```ruby
    assert Date.today.in?(..Date.tomorrow)
    assert_not Date.today.in?(Date.tomorrow..)
    ```

    *Ignacio Galindo*

*   `config.i18n.raise_on_missing_translations = true` now raises on any missing translation.

    Previously it would only raise when called in a view or controller. Now it will raise
    anytime `I18n.t` is provided an unrecognised key.

    If you do not want this behaviour, you can customise the i18n exception handler. See the
    upgrading guide or i18n guide for more information.

    *Alex Ghiculescu*

*   `ActiveSupport::CurrentAttributes` now raises if a restricted attribute name is used.

    Attributes such as `set` and `reset` cannot be used as they clash with the
    `CurrentAttributes` public API.

    *Alex Ghiculescu*

*   `HashWithIndifferentAccess#transform_keys` now takes a Hash argument, just
    as Ruby's `Hash#transform_keys` does.

    *Akira Matsuda*

*   `delegate` now defines method with proper arity when delegating to a Class.
    With this change, it defines faster method (3.5x faster with no argument).
    However, in order to gain this benefit, the delegation target method has to
    be defined before declaring the delegation.

    ```ruby
    # This defines 3.5 times faster method than before
    class C
      def self.x() end
      delegate :x, to: :class
    end

    class C
      # This works but silently falls back to old behavior because
      # `delegate` cannot find the definition of `x`
      delegate :x, to: :class
      def self.x() end
    end
    ```

    *Akira Matsuda*

*   `assert_difference` message now includes what changed.

    This makes it easier to debug non-obvious failures.

    Before:

    ```
    "User.count" didn't change by 32.
    Expected: 1611
      Actual: 1579
    ```

    After:

    ```
    "User.count" didn't change by 32, but by 0.
    Expected: 1611
      Actual: 1579
    ```

    *Alex Ghiculescu*

*   Add ability to match exception messages to `assert_raises` assertion

    Instead of this
    ```ruby
    error = assert_raises(ArgumentError) do
      perform_service(param: 'exception')
    end
    assert_match(/incorrect param/i, error.message)
    ```

    you can now write this
    ```ruby
    assert_raises(ArgumentError, match: /incorrect param/i) do
      perform_service(param: 'exception')
    end
    ```

    *fatkodima*

*   Add `Rails.env.local?` shorthand for `Rails.env.development? || Rails.env.test?`.

    *DHH*

*   `ActiveSupport::Testing::TimeHelpers` now accepts named `with_usec` argument
    to `freeze_time`, `travel`, and `travel_to` methods. Passing true prevents
    truncating the destination time with `change(usec: 0)`.

    *KevSlashNull*, and *serprex*

*   `ActiveSupport::CurrentAttributes.resets` now accepts a method name

    The block API is still the recommended approach, but now both APIs are supported:

    ```ruby
    class Current < ActiveSupport::CurrentAttributes
      resets { Time.zone = nil }
      resets :clear_time_zone
    end
    ```

    *Alex Ghiculescu*

*   Ensure `ActiveSupport::Testing::Isolation::Forking` closes pipes

    Previously, `Forking.run_in_isolation` opened two ends of a pipe. The fork
    process closed the read end, wrote to it, and then terminated (which
    presumably closed the file descriptors on its end). The parent process
    closed the write end, read from it, and returned, never closing the read
    end.

    This resulted in an accumulation of open file descriptors, which could
    cause errors if the limit is reached.

    *Sam Bostock*

*   Fix `Time#change` and `Time#advance` for times around the end of Daylight
    Saving Time.

    Previously, when `Time#change` or `Time#advance` constructed a time inside
    the final stretch of Daylight Saving Time (DST), the non-DST offset would
    always be chosen for local times:

    ```ruby
    # DST ended just before 2021-11-07 2:00:00 AM in US/Eastern.
    ENV["TZ"] = "US/Eastern"

    time = Time.local(2021, 11, 07, 00, 59, 59) + 1
    # => 2021-11-07 01:00:00 -0400
    time.change(day: 07)
    # => 2021-11-07 01:00:00 -0500
    time.advance(seconds: 0)
    # => 2021-11-07 01:00:00 -0500

    time = Time.local(2021, 11, 06, 01, 00, 00)
    # => 2021-11-06 01:00:00 -0400
    time.change(day: 07)
    # => 2021-11-07 01:00:00 -0500
    time.advance(days: 1)
    # => 2021-11-07 01:00:00 -0500
    ```

    And the DST offset would always be chosen for times with a `TimeZone`
    object:

    ```ruby
    Time.zone = "US/Eastern"

    time = Time.new(2021, 11, 07, 02, 00, 00, Time.zone) - 3600
    # => 2021-11-07 01:00:00 -0500
    time.change(day: 07)
    # => 2021-11-07 01:00:00 -0400
    time.advance(seconds: 0)
    # => 2021-11-07 01:00:00 -0400

    time = Time.new(2021, 11, 8, 01, 00, 00, Time.zone)
    # => 2021-11-08 01:00:00 -0500
    time.change(day: 07)
    # => 2021-11-07 01:00:00 -0400
    time.advance(days: -1)
    # => 2021-11-07 01:00:00 -0400
    ```

    Now, `Time#change` and `Time#advance` will choose the offset that matches
    the original time's offset when possible:

    ```ruby
    ENV["TZ"] = "US/Eastern"

    time = Time.local(2021, 11, 07, 00, 59, 59) + 1
    # => 2021-11-07 01:00:00 -0400
    time.change(day: 07)
    # => 2021-11-07 01:00:00 -0400
    time.advance(seconds: 0)
    # => 2021-11-07 01:00:00 -0400

    time = Time.local(2021, 11, 06, 01, 00, 00)
    # => 2021-11-06 01:00:00 -0400
    time.change(day: 07)
    # => 2021-11-07 01:00:00 -0400
    time.advance(days: 1)
    # => 2021-11-07 01:00:00 -0400

    Time.zone = "US/Eastern"

    time = Time.new(2021, 11, 07, 02, 00, 00, Time.zone) - 3600
    # => 2021-11-07 01:00:00 -0500
    time.change(day: 07)
    # => 2021-11-07 01:00:00 -0500
    time.advance(seconds: 0)
    # => 2021-11-07 01:00:00 -0500

    time = Time.new(2021, 11, 8, 01, 00, 00, Time.zone)
    # => 2021-11-08 01:00:00 -0500
    time.change(day: 07)
    # => 2021-11-07 01:00:00 -0500
    time.advance(days: -1)
    # => 2021-11-07 01:00:00 -0500
    ```

    *Kevin Hall*, *Takayoshi Nishida*, and *Jonathan Hefner*

*   Fix MemoryStore to preserve entries TTL when incrementing or decrementing

    This is to be more consistent with how MemCachedStore and RedisCacheStore behaves.

    *Jean Boussier*

*   `Rails.error.handle` and `Rails.error.record` filter now by multiple error classes.

    ```ruby
    Rails.error.handle(IOError, ArgumentError) do
      1 + '1' # raises TypeError
    end
    1 + 1 # TypeErrors are not IOErrors or ArgumentError, so this will *not* be handled
    ```

    *Martin Spickermann*

*   `Class#subclasses` and `Class#descendants` now automatically filter reloaded classes.

    Previously they could return old implementations of reloadable classes that have been
    dereferenced but not yet garbage collected.

    They now automatically filter such classes like `DescendantTracker#subclasses` and
    `DescendantTracker#descendants`.

    *Jean Boussier*

*   `Rails.error.report` now marks errors as reported to avoid reporting them twice.

    In some cases, users might want to report errors explicitly with some extra context
    before letting it bubble up.

    This also allows to safely catch and report errors outside of the execution context.

    *Jean Boussier*

*   Add `assert_error_reported` and `assert_no_error_reported`

    Allows to easily asserts an error happened but was handled

    ```ruby
    report = assert_error_reported(IOError) do
      # ...
    end
    assert_equal "Oops", report.error.message
    assert_equal "admin", report.context[:section]
    assert_equal :warning, report.severity
    assert_predicate report, :handled?
    ```

    *Jean Boussier*

*   `ActiveSupport::Deprecation` behavior callbacks can now receive the
    deprecator instance as an argument.  This makes it easier for such callbacks
    to change their behavior based on the deprecator's state.  For example,
    based on the deprecator's `debug` flag.

    3-arity and splat-args callbacks such as the following will now be passed
    the deprecator instance as their third argument:

    * `->(message, callstack, deprecator) { ... }`
    * `->(*args) { ... }`
    * `->(message, *other_args) { ... }`

    2-arity and 4-arity callbacks such as the following will continue to behave
    the same as before:

    * `->(message, callstack) { ... }`
    * `->(message, callstack, deprecation_horizon, gem_name) { ... }`
    * `->(message, callstack, *deprecation_details) { ... }`

    *Jonathan Hefner*

*   `ActiveSupport::Deprecation#disallowed_warnings` now affects the instance on
    which it is configured.

    This means that individual `ActiveSupport::Deprecation` instances can be
    configured with their own disallowed warnings, and the global
    `ActiveSupport::Deprecation.disallowed_warnings` now only affects the global
    `ActiveSupport::Deprecation.warn`.

    **Before**

    ```ruby
    ActiveSupport::Deprecation.disallowed_warnings = ["foo"]
    deprecator = ActiveSupport::Deprecation.new("2.0", "MyCoolGem")
    deprecator.disallowed_warnings = ["bar"]

    ActiveSupport::Deprecation.warn("foo") # => raise ActiveSupport::DeprecationException
    ActiveSupport::Deprecation.warn("bar") # => print "DEPRECATION WARNING: bar"
    deprecator.warn("foo")                 # => raise ActiveSupport::DeprecationException
    deprecator.warn("bar")                 # => print "DEPRECATION WARNING: bar"
    ```

    **After**

    ```ruby
    ActiveSupport::Deprecation.disallowed_warnings = ["foo"]
    deprecator = ActiveSupport::Deprecation.new("2.0", "MyCoolGem")
    deprecator.disallowed_warnings = ["bar"]

    ActiveSupport::Deprecation.warn("foo") # => raise ActiveSupport::DeprecationException
    ActiveSupport::Deprecation.warn("bar") # => print "DEPRECATION WARNING: bar"
    deprecator.warn("foo")                 # => print "DEPRECATION WARNING: foo"
    deprecator.warn("bar")                 # => raise ActiveSupport::DeprecationException
    ```

    Note that global `ActiveSupport::Deprecation` methods such as `ActiveSupport::Deprecation.warn`
    and `ActiveSupport::Deprecation.disallowed_warnings` have been deprecated.

    *Jonathan Hefner*

*   Add italic and underline support to `ActiveSupport::LogSubscriber#color`

    Previously, only bold text was supported via a positional argument.
    This allows for bold, italic, and underline options to be specified
    for colored logs.

    ```ruby
    info color("Hello world!", :red, bold: true, underline: true)
    ```

    *Gannon McGibbon*

*   Add `String#downcase_first` method.

    This method is the corollary of `String#upcase_first`.

    *Mark Schneider*

*   `thread_mattr_accessor` will call `.dup.freeze` on non-frozen default values.

    This provides a basic level of protection against different threads trying
    to mutate a shared default object.

    *Jonathan Hefner*

*   Add `raise_on_invalid_cache_expiration_time` config to `ActiveSupport::Cache::Store`

    Specifies if an `ArgumentError` should be raised if `Rails.cache` `fetch` or
    `write` are given an invalid `expires_at` or `expires_in` time.

    Options are `true`, and `false`. If `false`, the exception will be reported
    as `handled` and logged instead. Defaults to `true` if `config.load_defaults >= 7.1`.

     *Trevor Turk*

*   `ActiveSupport::Cache::Store#fetch` now passes an options accessor to the block.

    It makes possible to override cache options:

        Rails.cache.fetch("3rd-party-token") do |name, options|
          token = fetch_token_from_remote
          # set cache's TTL to match token's TTL
          options.expires_in = token.expires_in
          token
        end

    *Andrii Gladkyi*, *Jean Boussier*

*   `default` option of `thread_mattr_accessor` now applies through inheritance and
    also across new threads.

    Previously, the `default` value provided was set only at the moment of defining
    the attribute writer, which would cause the attribute to be uninitialized in
    descendants and in other threads.

    Fixes #43312.

    *Thierry Deo*

*   Redis cache store is now compatible with redis-rb 5.0.

    *Jean Boussier*

*   Add `skip_nil:` support to `ActiveSupport::Cache::Store#fetch_multi`.

    *Daniel Alfaro*

*   Add `quarter` method to date/time

    *Matt Swanson*

*   Fix `NoMethodError` on custom `ActiveSupport::Deprecation` behavior.

    `ActiveSupport::Deprecation.behavior=` was supposed to accept any object
    that responds to `call`, but in fact its internal implementation assumed that
    this object could respond to `arity`, so it was restricted to only `Proc` objects.

    This change removes this `arity` restriction of custom behaviors.

    *Ryo Nakamura*

*   Support `:url_safe` option for `MessageEncryptor`.

    The `MessageEncryptor` constructor now accepts a `:url_safe` option, similar
    to the `MessageVerifier` constructor.  When enabled, this option ensures
    that messages use a URL-safe encoding.

    *Jonathan Hefner*

*   Add `url_safe` option to `ActiveSupport::MessageVerifier` initializer

    `ActiveSupport::MessageVerifier.new` now takes optional `url_safe` argument.
    It can generate URL-safe strings by passing `url_safe: true`.

    ```ruby
    verifier = ActiveSupport::MessageVerifier.new(url_safe: true)
    message = verifier.generate(data) # => URL-safe string
    ```

    This option is `false` by default to be backwards compatible.

    *Shouichi Kamiya*

*   Enable connection pooling by default for `MemCacheStore` and `RedisCacheStore`.

    If you want to disable connection pooling, set `:pool` option to `false` when configuring the cache store:

    ```ruby
    config.cache_store = :mem_cache_store, "cache.example.com", pool: false
    ```

    *fatkodima*

*   Add `force:` support to `ActiveSupport::Cache::Store#fetch_multi`.

    *fatkodima*

*   Deprecated `:pool_size` and `:pool_timeout` options for configuring connection pooling in cache stores.

    Use `pool: true` to enable pooling with default settings:

    ```ruby
    config.cache_store = :redis_cache_store, pool: true
    ```

    Or pass individual options via `:pool` option:

    ```ruby
    config.cache_store = :redis_cache_store, pool: { size: 10, timeout: 2 }
    ```

    *fatkodima*

*   Allow #increment and #decrement methods of `ActiveSupport::Cache::Store`
    subclasses to set new values.

    Previously incrementing or decrementing an unset key would fail and return
    nil. A default will now be assumed and the key will be created.

    *Andrej Blagojević*, *Eugene Kenny*

*   Add `skip_nil:` support to `RedisCacheStore`

    *Joey Paris*

*   `ActiveSupport::Cache::MemoryStore#write(name, val, unless_exist:true)` now
    correctly writes expired keys.

    *Alan Savage*

*   `ActiveSupport::ErrorReporter` now accepts and forward a `source:` parameter.

    This allow libraries to signal the origin of the errors, and reporters
    to easily ignore some sources.

    *Jean Boussier*

*   Fix and add protections for XSS in `ActionView::Helpers` and `ERB::Util`.

    Add the method `ERB::Util.xml_name_escape` to escape dangerous characters
    in names of tags and names of attributes, following the specification of XML.

    *Álvaro Martín Fraguas*

*   Respect `ActiveSupport::Logger.new`'s `:formatter` keyword argument

    The stdlib `Logger::new` allows passing a `:formatter` keyword argument to
    set the logger's formatter. Previously `ActiveSupport::Logger.new` ignored
    that argument by always setting the formatter to an instance of
    `ActiveSupport::Logger::SimpleFormatter`.

    *Steven Harman*

*   Deprecate preserving the pre-Ruby 2.4 behavior of `to_time`

    With Ruby 2.4+ the default for +to_time+ changed from converting to the
    local system time to preserving the offset of the receiver. At the time Rails
    supported older versions of Ruby so a compatibility layer was added to assist
    in the migration process. From Rails 5.0 new applications have defaulted to
    the Ruby 2.4+ behavior and since Rails 7.0 now only supports Ruby 2.7+
    this compatibility layer can be safely removed.

    To minimize any noise generated the deprecation warning only appears when the
    setting is configured to `false` as that is the only scenario where the
    removal of the compatibility layer has any effect.

    *Andrew White*

*   `Pathname.blank?` only returns true for `Pathname.new("")`

    Previously it would end up calling `Pathname#empty?` which returned true
    if the path existed and was an empty directory or file.

    That behavior was unlikely to be expected.

    *Jean Boussier*

*   Deprecate `Notification::Event`'s `#children` and `#parent_of?`

    *John Hawthorn*

*   Change the default serializer of `ActiveSupport::MessageVerifier` from
    `Marshal` to `ActiveSupport::JSON` when using `config.load_defaults 7.1`.

    Messages serialized with `Marshal` can still be read, but new messages will
    be serialized with `ActiveSupport::JSON`. For more information, see
    https://guides.rubyonrails.org/v7.1/configuring.html#config-active-support-message-serializer.

    *Saba Kiaei*, *David Buckley*, and *Jonathan Hefner*

*   Change the default serializer of `ActiveSupport::MessageEncryptor` from
    `Marshal` to `ActiveSupport::JSON` when using `config.load_defaults 7.1`.

    Messages serialized with `Marshal` can still be read, but new messages will
    be serialized with `ActiveSupport::JSON`. For more information, see
    https://guides.rubyonrails.org/v7.1/configuring.html#config-active-support-message-serializer.

    *Zack Deveau*, *Martin Gingras*, and *Jonathan Hefner*

*   Add `ActiveSupport::TestCase#stub_const` to stub a constant for the duration of a yield.

    *DHH*

*   Fix `ActiveSupport::EncryptedConfiguration` to be compatible with Psych 4

    *Stephen Sugden*

*   Improve `File.atomic_write` error handling

    *Daniel Pepper*

*   Fix `Class#descendants` and `DescendantsTracker#descendants` compatibility with Ruby 3.1.

    [The native `Class#descendants` was reverted prior to Ruby 3.1 release](https://bugs.ruby-lang.org/issues/14394#note-33),
    but `Class#subclasses` was kept, breaking the feature detection.

    *Jean Boussier*

Please check [7-0-stable](https://github.com/rails/rails/blob/7-0-stable/activesupport/CHANGELOG.md) for previous changes.
