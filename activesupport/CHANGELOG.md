*   Remove deprecated `ActiveSupport::Notifications::Instrumenter#end=`.

    *Rafael Mendonça França*

*   Deprecate `ActiveSupport::Multibyte::Unicode.default_normalization_form`.

    *Rafael Mendonça França*

*   Remove deprecated `ActiveSupport::Multibyte::Unicode.pack_graphemes`,
    `ActiveSupport::Multibyte::Unicode.unpack_graphemes`,
    `ActiveSupport::Multibyte::Unicode.normalize`,
    `ActiveSupport::Multibyte::Unicode.downcase`,
    `ActiveSupport::Multibyte::Unicode.upcase` and `ActiveSupport::Multibyte::Unicode.swapcase`.

    *Rafael Mendonça França*

*   Remove deprecated `ActiveSupport::Multibyte::Chars#consumes?` and `ActiveSupport::Multibyte::Chars#normalize`.

    *Rafael Mendonça França*

*   Remove deprecated file `active_support/core_ext/range/include_range`.

    *Rafael Mendonça França*

*   Remove deprecated file `active_support/core_ext/hash/transform_values`.

    *Rafael Mendonça França*

*   Remove deprecated file `active_support/core_ext/hash/compact`.

    *Rafael Mendonça França*

*   Remove deprecated file `active_support/core_ext/array/prepend_and_append`.

    *Rafael Mendonça França*

*   Remove deprecated file `active_support/core_ext/numeric/inquiry`.

    *Rafael Mendonça França*

*   Remove deprecated file `active_support/core_ext/module/reachable`.

    *Rafael Mendonça França*

*   Remove deprecated `Module#parent_name`, `Module#parent` and `Module#parents`.

    *Rafael Mendonça França*

*   Remove deprecated `ActiveSupport::LoggerThreadSafeLevel#after_initialize`.

    *Rafael Mendonça França*

*   Remove deprecated `LoggerSilence` constant.

    *Rafael Mendonça França*

*   Remove deprecated fallback to `I18n.default_local` when `config.i18n.fallbacks` is empty.

    *Rafael Mendonça França*

*   Remove entries from local cache on `RedisCacheStore#delete_matched`

    Fixes #38627

    *ojab*

*   Speed up `ActiveSupport::SecurityUtils.fixed_length_secure_compare` by using
    `OpenSSL.fixed_length_secure_compare`, if available.

    *Nate Matykiewicz*

*   `ActiveSupport::Cache::MemCacheStore` now checks `ENV["MEMCACHE_SERVERS"]` before falling back to `"localhost:11211"` if configured without any addresses.

    ```ruby
    config.cache_store = :mem_cache_store

    # is now equivalent to

    config.cache_store = :mem_cache_store, ENV["MEMCACHE_SERVERS"] || "localhost:11211"

    # instead of

    config.cache_store = :mem_cache_store, "localhost:11211" # ignores ENV["MEMCACHE_SERVERS"]
    ```

    *Sam Bostock*

*   `ActiveSupport::Subscriber#attach_to` now accepts an `inherit_all:` argument. When set to true,
    it allows a subscriber to receive events for methods defined in the subscriber's ancestor class(es).

    ```ruby
    class ActionControllerSubscriber < ActiveSupport::Subscriber
      attach_to :action_controller

      def start_processing(event)
        info "Processing by #{event.payload[:controller]}##{event.payload[:action]} as #{format}"
      end

      def redirect_to(event)
        info { "Redirected to #{event.payload[:location]}" }
      end
    end

    # We detach ActionControllerSubscriber from the :action_controller namespace so that our CustomActionControllerSubscriber
    # can provide its own instrumentation for certain events in the namespace
    ActionControllerSubscriber.detach_from(:action_controller)

    class CustomActionControllerSubscriber < ActionControllerSubscriber
      attach_to :action_controller, inherit_all: true

      def start_processing(event)
        info "A custom response to start_processing events"
      end

      # => CustomActionControllerSubscriber will process events for "start_processing.action_controller" notifications
      # using its own #start_processing implementation, while retaining ActionControllerSubscriber's instrumentation
      # for "redirect_to.action_controller" notifications
    end
    ```

    *Adrianna Chang*

*   Allow the digest class used to generate non-sensitive digests to be configured with `config.active_support.hash_digest_class`.

    `config.active_support.use_sha1_digests` is deprecated in favour of `config.active_support.hash_digest_class = ::Digest::SHA1`.

    *Dirkjan Bussink*

*   Fix bug to make memcached write_entry expire correctly with unless_exist

    *Jye Lee*

*   Add `ActiveSupport::Duration` conversion methods

    `in_seconds`, `in_minutes`, `in_hours`, `in_days`, `in_weeks`, `in_months`, and `in_years` return the respective duration covered.

    *Jason York*

*   Fixed issue in `ActiveSupport::Cache::RedisCacheStore` not passing options
    to `read_multi` causing `fetch_multi` to not work properly

    *Rajesh Sharma*

*   Fixed issue in `ActiveSupport::Cache::MemCacheStore` which caused duplicate compression,
    and caused the provided `compression_threshold` to not be respected.

    *Max Gurewitz*

*   Prevent `RedisCacheStore` and `MemCacheStore` from performing compression
    when reading entries written with `raw: true`.

    *Max Gurewitz*

*   `URI.parser` is deprecated and will be removed in Rails 6.2. Use
    `URI::DEFAULT_PARSER` instead.

    *Jean Boussier*

*   `require_dependency` has been documented to be _obsolete_ in `:zeitwerk`
    mode. The method is not deprecated as such (yet), but applications are
    encouraged to not use it.

    In `:zeitwerk` mode, semantics match Ruby's and you do not need to be
    defensive with load order. Just refer to classes and modules normally. If
    the constant name is dynamic, camelize if needed, and constantize.

    *Xavier Noria*

*   Add 3rd person aliases of `Symbol#start_with?` and `Symbol#end_with?`.

    ```ruby
    :foo.starts_with?("f") # => true
    :foo.ends_with?("o")   # => true
    ```

    *Ryuta Kamizono*

*   Add override of unary plus for `ActiveSupport::Duration`.

    `+ 1.second` is now identical to `+1.second` to prevent errors
    where a seemingly innocent change of formatting leads to a change in the code behavior.

    Before:
    ```ruby
    +1.second.class
    # => ActiveSupport::Duration
    (+ 1.second).class
    # => Integer
    ```

    After:
    ```ruby
    +1.second.class
    # => ActiveSupport::Duration
    (+ 1.second).class
    # => ActiveSupport::Duration
    ```

    Fixes #39079.

    *Roman Kushnir*

*   Add subsec to `ActiveSupport::TimeWithZone#inspect`.

    Before:

        Time.at(1498099140).in_time_zone.inspect
        # => "Thu, 22 Jun 2017 02:39:00 UTC +00:00"
        Time.at(1498099140, 123456780, :nsec).in_time_zone.inspect
        # => "Thu, 22 Jun 2017 02:39:00 UTC +00:00"
        Time.at(1498099140 + Rational("1/3")).in_time_zone.inspect
        # => "Thu, 22 Jun 2017 02:39:00 UTC +00:00"

    After:

        Time.at(1498099140).in_time_zone.inspect
        # => "Thu, 22 Jun 2017 02:39:00.000000000 UTC +00:00"
        Time.at(1498099140, 123456780, :nsec).in_time_zone.inspect
        # => "Thu, 22 Jun 2017 02:39:00.123456780 UTC +00:00"
        Time.at(1498099140 + Rational("1/3")).in_time_zone.inspect
        # => "Thu, 22 Jun 2017 02:39:00.333333333 UTC +00:00"

    *akinomaeni*

*   Calling `ActiveSupport::TaggedLogging#tagged` without a block now returns a tagged logger.

    ```ruby
    logger.tagged("BCX").info("Funky time!") # => [BCX] Funky time!
    ```

    *Eugene Kenny*

*   Align `Range#cover?` extension behavior with Ruby behavior for backwards ranges.

    `(1..10).cover?(5..3)` now returns `false`, as it does in plain Ruby.

    Also update `#include?` and `#===` behavior to match.

    *Michael Groeneman*

*   Update to TZInfo v2.0.0.

    This changes the output of `ActiveSupport::TimeZone.utc_to_local`, but
    can be controlled with the
    `ActiveSupport.utc_to_local_returns_utc_offset_times` config.

    New Rails 6.1 apps have it enabled by default, existing apps can upgrade
    via the config in config/initializers/new_framework_defaults_6_1.rb

    See the `utc_to_local_returns_utc_offset_times` documentation for details.

    *Phil Ross*, *Jared Beck*

*   Add Date and Time `#yesterday?` and `#tomorrow?` alongside `#today?`.

    Aliased to `#prev_day?` and `#next_day?` to match the existing `#prev/next_day` methods.

    *Jatin Dhankhar*

*   Add `Enumerable#pick` to complement `ActiveRecord::Relation#pick`.

    *Eugene Kenny*

*   [Breaking change] `ActiveSupport::Callbacks#halted_callback_hook` now receive a 2nd argument:

    `ActiveSupport::Callbacks#halted_callback_hook` now receive the name of the callback
    being halted as second argument.
    This change will allow you to differentiate which callbacks halted the chain
    and act accordingly.

    ```ruby
      class Book < ApplicationRecord
        before_save { throw(:abort) }
        before_create { throw(:abort) }

        def halted_callback_hook(filter, callback_name)
          Rails.logger.info("Book couldn't be #{callback_name}d")
        end

        Book.create # => "Book couldn't be created"
        book.save # => "Book couldn't be saved"
      end
    ```

    *Edouard Chin*

*   Support `prepend` with `ActiveSupport::Concern`.

    Allows a module with `extend ActiveSupport::Concern` to be prepended.

        module Imposter
          extend ActiveSupport::Concern

          # Same as `included`, except only run when prepended.
          prepended do
          end
        end

        class Person
          prepend Imposter
        end

    Class methods are prepended to the base class, concerning is also
    updated: `concerning :Imposter, prepend: true do`.

    *Jason Karns*, *Elia Schito*

*   Deprecate using `Range#include?` method to check the inclusion of a value
    in a date time range. It is recommended to use `Range#cover?` method
    instead of `Range#include?` to check the inclusion of a value
    in a date time range.

    *Vishal Telangre*

*   Support added for a `round_mode` parameter, in all number helpers. (See: `BigDecimal::mode`.)

    ```ruby
    number_to_currency(1234567890.50, precision: 0, round_mode: :half_down) # => "$1,234,567,890"
    number_to_percentage(302.24398923423, precision: 5, round_mode: :down) # => "302.24398%"
    number_to_rounded(389.32314, precision: 0, round_mode: :ceil) # => "390"
    number_to_human_size(483989, precision: 2, round_mode: :up) # => "480 KB"
    number_to_human(489939, precision: 2, round_mode: :floor) # => "480 Thousand"

    485000.to_s(:human, precision: 2, round_mode: :half_even) # => "480 Thousand"
    ```

    *Tom Lord*

*   `Array#to_sentence` no longer returns a frozen string.

    Before:

        ['one', 'two'].to_sentence.frozen?
        # => true

    After:

        ['one', 'two'].to_sentence.frozen?
        # => false

    *Nicolas Dular*

*   When an instance of `ActiveSupport::Duration` is converted to an `iso8601` duration string, if `weeks` are mixed with `date` parts, the `week` part will be converted to days.
    This keeps the parser and serializer on the same page.

    ```ruby
    duration = ActiveSupport::Duration.build(1000000)
    # 1 week, 4 days, 13 hours, 46 minutes, and 40.0 seconds

    duration_iso = duration.iso8601
    # P11DT13H46M40S

    ActiveSupport::Duration.parse(duration_iso)
    # 11 days, 13 hours, 46 minutes, and 40 seconds

    duration = ActiveSupport::Duration.build(604800)
    # 1 week

    duration_iso = duration.iso8601
    # P1W

    ActiveSupport::Duration.parse(duration_iso)
    # 1 week
    ```

    *Abhishek Sarkar*

*   Add block support to `ActiveSupport::Testing::TimeHelpers#travel_back`.

    *Tim Masliuchenko*

*   Update `ActiveSupport::Messages::Metadata#fresh?` to work for cookies with expiry set when
    `ActiveSupport.parse_json_times = true`.

    *Christian Gregg*

*   Support symbolic links for `content_path` in `ActiveSupport::EncryptedFile`.

    *Takumi Shotoku*

*   Improve `Range#===`, `Range#include?`, and `Range#cover?` to work with beginless (startless)
    and endless range targets.

    *Allen Hsu*, *Andrew Hodgkinson*

*   Don't use `Process#clock_gettime(CLOCK_THREAD_CPUTIME_ID)` on Solaris.

    *Iain Beeston*

*   Prevent `ActiveSupport::Duration.build(value)` from creating instances of
    `ActiveSupport::Duration` unless `value` is of type `Numeric`.

    Addresses the errant set of behaviours described in #37012 where
    `ActiveSupport::Duration` comparisons would fail confusingly
    or return unexpected results when comparing durations built from instances of `String`.

    Before:

        small_duration_from_string = ActiveSupport::Duration.build('9')
        large_duration_from_string = ActiveSupport::Duration.build('100000000000000')
        small_duration_from_int = ActiveSupport::Duration.build(9)

        large_duration_from_string > small_duration_from_string
        # => false

        small_duration_from_string == small_duration_from_int
        # => false

        small_duration_from_int < large_duration_from_string
        # => ArgumentError (comparison of ActiveSupport::Duration::Scalar with ActiveSupport::Duration failed)

        large_duration_from_string > small_duration_from_int
        # => ArgumentError (comparison of String with ActiveSupport::Duration failed)

    After:

        small_duration_from_string = ActiveSupport::Duration.build('9')
        # => TypeError (can't build an ActiveSupport::Duration from a String)

    *Alexei Emam*

*   Add `ActiveSupport::Cache::Store#delete_multi` method to delete multiple keys from the cache store.

    *Peter Zhu*

*   Support multiple arguments in `HashWithIndifferentAccess` for `merge` and `update` methods, to
    follow Ruby 2.6 addition.

    *Wojciech Wnętrzak*

*   Allow initializing `thread_mattr_*` attributes via `:default` option.

        class Scraper
          thread_mattr_reader :client, default: Api::Client.new
        end

    *Guilherme Mansur*

*   Add `compact_blank` for those times when you want to remove #blank? values from
    an Enumerable (also `compact_blank!` on Hash, Array, ActionController::Parameters).

    *Dana Sherson*

*   Make ActiveSupport::Logger Fiber-safe.

    Use `Fiber.current.__id__` in `ActiveSupport::Logger#local_level=` in order
    to make log level local to Ruby Fibers in addition to Threads.

    Example:

        logger = ActiveSupport::Logger.new(STDOUT)
        logger.level = 1
        puts "Main is debug? #{logger.debug?}"

        Fiber.new {
          logger.local_level = 0
          puts "Thread is debug? #{logger.debug?}"
        }.resume

        puts "Main is debug? #{logger.debug?}"

    Before:

        Main is debug? false
        Thread is debug? true
        Main is debug? true

    After:

        Main is debug? false
        Thread is debug? true
        Main is debug? false

    Fixes #36752.

    *Alexander Varnin*

*   Allow the `on_rotation` proc used when decrypting/verifying a message to be
    passed at the constructor level.

    Before:

        crypt = ActiveSupport::MessageEncryptor.new('long_secret')
        crypt.decrypt_and_verify(encrypted_message, on_rotation: proc { ... })
        crypt.decrypt_and_verify(another_encrypted_message, on_rotation: proc { ... })

    After:

        crypt = ActiveSupport::MessageEncryptor.new('long_secret', on_rotation: proc { ... })
        crypt.decrypt_and_verify(encrypted_message)
        crypt.decrypt_and_verify(another_encrypted_message)

    *Edouard Chin*

*   `delegate_missing_to` would raise a `DelegationError` if the object
    delegated to was `nil`. Now the `allow_nil` option has been added to enable
    the user to specify they want `nil` returned in this case.

    *Matthew Tanous*

*   `truncate` would return the original string if it was too short to be truncated
    and a frozen string if it were long enough to be truncated. Now truncate will
    consistently return an unfrozen string regardless. This behavior is consistent
    with `gsub` and `strip`.

    Before:

        'foobar'.truncate(5).frozen?
        # => true
        'foobar'.truncate(6).frozen?
        # => false

    After:

        'foobar'.truncate(5).frozen?
        # => false
        'foobar'.truncate(6).frozen?
        # => false

    *Jordan Thomas*


Please check [6-0-stable](https://github.com/rails/rails/blob/6-0-stable/activesupport/CHANGELOG.md) for previous changes.
