## Rails 5.0.2 (March 01, 2017) ##

*   In Core Extensions, make `MarshalWithAutoloading#load` pass through the second, optional
    argument for `Marshal#load( source [, proc] )`. This way we don't have to do 
    `Marshal.method(:load).super_method.call(sourse, proc)` just to be able to pass a proc.

    *Jeff Latz*

*   `ActiveSupport::Gzip.decompress` now checks checksum and length in footer.

    *Dylan Thacker-Smith*

*   Cache `ActiveSupport::TimeWithZone#to_datetime` before freezing.

    *Adam Rice*


## Rails 5.0.1 (December 21, 2016) ##

*   No changes.


## Rails 5.0.1.rc2 (December 10, 2016) ##

*   No changes.


## Rails 5.0.1.rc1 (December 01, 2016) ##

*   Ensure duration parsing is consistent across DST changes

    Previously `ActiveSupport::Duration.parse` used `Time.current` and
    `Time#advance` to calculate the number of seconds in the duration
    from an arbitrary collection of parts. However as `advance` tries to
    be consistent across DST boundaries this meant that either the
    duration was shorter or longer depending on the time of year.

    This was fixed by using an absolute reference point in UTC which
    isn't subject to DST transitions. An arbitrary date of Jan 1st, 2000
    was chosen for no other reason that it seemed appropriate.

    Additionally, duration parsing should now be marginally faster as we
    are no longer creating instances of `ActiveSupport::TimeWithZone`
    every time we parse a duration string.

    Fixes #26941.

    *Andrew White*

*   Fix `DateAndTime::Calculations#copy_time_to`. Copy `nsec` instead of `usec`.

    Jumping forward or backward between weeks now preserves nanosecond digits.

    *Josua Schmid*

*   Avoid bumping the class serial when invoking executor.

    *Matthew Draper*

*   Fix `ActiveSupport::TimeWithZone#in` across DST boundaries.

    Previously calls to `in` were being sent to the non-DST aware
    method `Time#since` via `method_missing`. It is now aliased to
    the DST aware `ActiveSupport::TimeWithZone#+` which handles
    transitions across DST boundaries, e.g:

        Time.zone = "US/Eastern"

        t = Time.zone.local(2016,11,6,1)
        # => Sun, 06 Nov 2016 01:00:00 EDT -05:00

        t.in(1.hour)
        # => Sun, 06 Nov 2016 01:00:00 EST -05:00

    Fixes #26580.

    *Thomas Balthazar*

*   Fix `thread_mattr_accessor` subclass no longer overwrites parent.

    Assigning a value to a subclass using `thread_mattr_accessor` no
    longer changes the value of the parent class. This brings the
    behavior inline with the documentation.

    Given:

        class Account
          thread_mattr_accessor :user
        end

        class Customer < Account
        end

        Account.user = "DHH"
        Customer.user = "Rafael"

    Before:

        Account.user  # => "Rafael"

    After:

        Account.user  # => "DHH"

    *Shinichi Maeshima*

*   Since weeks are no longer converted to days, add `:weeks` to the list of
    parts that `ActiveSupport::TimeWithZone` will recognize as possibly being
    of variable duration to take account of DST transitions.

    Fixes #26039.

    *Andrew White*

*   Fix `ActiveSupport::TimeZone#strptime`. Now raises `ArgumentError` when the
    given time doesn't match the format. The error is the same as the one given
    by Ruby's `Date.strptime`. Previously it raised
    `NoMethodError: undefined method empty? for nil:NilClass.` due to a bug.

    Fixes #25701.

    *John Gesimondo*


## Rails 5.0.0 (June 30, 2016) ##

*   Support parsing JSON time in ISO8601 local time strings in
    `ActiveSupport::JSON.decode` when `parse_json_times` is enabled.
    Strings in the format of `YYYY-MM-DD hh:mm:ss` (without a `Z` at
    the end) will be parsed in the local timezone (`Time.zone`). In
    addition, date strings (`YYYY-MM-DD`) are now parsed into `Date`
    objects.

    *Grzegorz Witek*

*   `Date.to_s` doesn't produce too many spaces. For example, `to_s(:short)`
    will now produce `01 Feb` instead of ` 1 Feb`.

    Fixes #25251.

    *Sean Griffin*

*   Rescuable: If a handler doesn't match the exception, check for handlers
    matching the exception's cause.

    *Jeremy Daer*

*   `ActiveSupport::Duration` supports weeks and hours.

        [1.hour.inspect, 1.hour.value, 1.hour.parts]
        # => ["3600 seconds", 3600, [[:seconds, 3600]]]   # Before
        # => ["1 hour", 3600, [[:hours, 1]]]              # After

        [1.week.inspect, 1.week.value, 1.week.parts]
        # => ["7 days", 604800, [[:days, 7]]]             # Before
        # => ["1 week", 604800, [[:weeks, 1]]]            # After

    This brings us into closer conformance with ISO8601 and relieves some
    astonishment about getting `1.hour.inspect # => 3600 seconds`.

    Compatibility: The duration's `value` remains the same, so apps using
    durations are oblivious to the new time periods. Apps, libraries, and
    plugins that work with the internal `parts` hash will need to broaden
    their time period handling to cover hours & weeks.

    *Andrey Novikov*

*   Time zones: Ensure that the UTC offset reflects DST changes that occurred
    since the app started. Removes UTC offset caching, reducing performance,
    but this is still relatively quick and isn't in any hot paths.

    *Alexey Shein*

*   Make `getlocal` and `getutc` always return instances of `Time` for
    `ActiveSupport::TimeWithZone` and `DateTime`. This eliminates a possible
    stack level too deep error in `to_time` where `ActiveSupport::TimeWithZone`
    was wrapping a `DateTime` instance. As a consequence of this the internal
    time value in `ActiveSupport::TimeWithZone` is now always an instance of
    `Time` in the UTC timezone, whether that's as the UTC time directly or
    a representation of the local time in the timezone. There should be no
    consequences of this internal change and if there are it's a bug due to
    leaky abstractions.

    *Andrew White*

*   Add `DateTime#subsec` to return the fraction of a second as a `Rational`.

    *Andrew White*

*   Add additional aliases for `DateTime#utc` to mirror the ones on
    `ActiveSupport::TimeWithZone` and `Time`.

    *Andrew White*

*   Add `DateTime#localtime` to return an instance of `Time` in the system's
    local timezone. Also aliased to `getlocal`.

    *Andrew White*, *Yuichiro Kaneko*

*   Add `Time#sec_fraction` to return the fraction of a second as a `Rational`.

    *Andrew White*

*   Add `ActiveSupport.to_time_preserves_timezone` config option to control
    how `to_time` handles timezones. In Ruby 2.4+ the behavior will change
    from converting to the local system timezone, to preserving the timezone
    of the receiver. This config option defaults to false so that apps made
    with earlier versions of Rails are not affected when upgrading, e.g:

        >> ENV['TZ'] = 'US/Eastern'

        >> "2016-04-23T10:23:12.000Z".to_time
        => "2016-04-23T06:23:12.000-04:00"

        >> ActiveSupport.to_time_preserves_timezone = true

        >> "2016-04-23T10:23:12.000Z".to_time
        => "2016-04-23T10:23:12.000Z"

    Fixes #24617.

    *Andrew White*

*   `ActiveSupport::TimeZone.country_zones(country_code)` looks up the
    country's time zones by its two-letter ISO3166 country code, e.g.

        >> ActiveSupport::TimeZone.country_zones(:jp).map(&:to_s)
        => ["(GMT+09:00) Osaka"]

        >> ActiveSupport::TimeZone.country_zones(:uy).map(&:to_s)
        => ["(GMT-03:00) Montevideo"]

    *Andrey Novikov*

*   `Array#sum` compat with Ruby 2.4's native method.

    Ruby 2.4 introduces `Array#sum`, but it only supports numeric elements,
    breaking our `Enumerable#sum` which supports arbitrary `Object#+`.
    To fix, override `Array#sum` with our compatible implementation.

    Native Ruby 2.4:

        %w[ a b ].sum
        # => TypeError: String can't be coerced into Fixnum

    With `Enumerable#sum` shim:

        %w[ a b ].sum
        # => 'ab'

    We tried shimming the fast path and falling back to the compatible path
    if it fails, but that ends up slower even in simple cases due to the cost
    of exception handling. Our only choice is to override the native `Array#sum`
    with our `Enumerable#sum`.

    *Jeremy Daer*

*   `ActiveSupport::Duration` supports ISO8601 formatting and parsing.

        ActiveSupport::Duration.parse('P3Y6M4DT12H30M5S')
        # => 3 years, 6 months, 4 days, 12 hours, 30 minutes, and 5 seconds

        (3.years + 3.days).iso8601
        # => "P3Y3D"

    Inspired by Arnau Siches' [ISO8601 gem](https://github.com/arnau/ISO8601/)
    and rewritten by Andrey Novikov with suggestions from Andrew White. Test
    data from the ISO8601 gem redistributed under MIT license.

    (Will be used to support the PostgreSQL interval data type.)

    *Andrey Novikov*, *Arnau Siches*, *Andrew White*

*   `Cache#fetch(key, force: true)` forces a cache miss, so it must be called
    with a block to provide a new value to cache. Fetching with `force: true`
    but without a block now raises ArgumentError.

        cache.fetch('key', force: true) # => ArgumentError

    *Santosh Wadghule*

*   Fix behavior of JSON encoding for `Exception`.

    *namusyaka*

*   Make `number_to_phone` format number with regexp pattern.

        number_to_phone(18812345678, pattern: /(\d{3})(\d{4})(\d{4})/)
        # => 188-1234-5678

    *Pan Gaoyong*

*   Match `String#to_time`'s behaviour to that of ruby's implementation for edge cases.

    `nil` is now returned instead of the current date if the string provided does
    contain time information, but none that is used to build the `Time` object.

    Fixes #22958.

    *Siim Liiser*

*   Rely on the native DateTime#<=> implementation to handle non-datetime like
    objects instead of returning `nil` ourselves. This restores the ability
    of `DateTime` instances to be compared with a `Numeric` that represents an
    astronomical julian day number.

    Fixes #24228.

    *Andrew White*

*   Add `String#upcase_first` method.

    *Glauco Custódio*, *bogdanvlviv*

*   Prevent `Marshal.load` from looping infinitely when trying to autoload a constant
    which resolves to a different name.

    *Olek Janiszewski*

*   Deprecate `Module.local_constants`. Please use `Module.constants(false)` instead.

    *Yuichiro Kaneko*

*   Publish `ActiveSupport::Executor` and `ActiveSupport::Reloader` APIs to allow
    components and libraries to manage, and participate in, the execution of
    application code, and the application reloading process.

    *Matthew Draper*

*   Deprecate arguments on `assert_nothing_raised`.

    `assert_nothing_raised` does not assert the arguments that have been passed
    in (usually a specific exception class) since the method only yields the
    block. So as not to confuse the users that the arguments have meaning, they
    are being deprecated.

    *Tara Scherner de la Fuente*

*   Make `benchmark('something', silence: true)` actually work.

    *DHH*

*   Add `#on_weekday?` method to `Date`, `Time`, and `DateTime`.

    `#on_weekday?` returns `true` if the receiving date/time does not fall on a Saturday
    or Sunday.

    *Vipul A M*

*   Add `Array#second_to_last` and `Array#third_to_last` methods.

    *Brian Christian*

*   Fix regression in `Hash#dig` for HashWithIndifferentAccess.

    *Jon Moss*

*   Change `number_to_currency` behavior for checking negativity.

    Used `to_f.negative` instead of using `to_f.phase` for checking negativity
    of a number in number_to_currency helper.
    This change works same for all cases except when number is "-0.0".

        -0.0.to_f.negative? => false
        -0.0.to_f.phase? => 3.14

    This change reverts changes from https://github.com/rails/rails/pull/6512.
    But it should be acceptable as we could not find any currency which
    supports negative zeros.

    *Prathamesh Sonpatki*, *Rafael Mendonça França*

*   Match `HashWithIndifferentAccess#default`'s behaviour with `Hash#default`.

    *David Cornu*

*   Adds `:exception_object` key to `ActiveSupport::Notifications::Instrumenter`
    payload when an exception is raised.

    Adds new key/value pair to payload when an exception is raised:
    e.g. `:exception_object => #<RuntimeError: FAIL>`.

    *Ryan T. Hosford*

*   Support extended grapheme clusters and UAX 29.

    *Adam Roben*

*   Add petabyte and exabyte numeric conversion.

    *Akshay Vishnoi*

*   Add thread_m/cattr_accessor/reader/writer suite of methods for declaring class and module variables that live per-thread.
    This makes it easy to declare per-thread globals that are encapsulated. Note: This is a sharp edge. A wild proliferation
    of globals is A Bad Thing. But like other sharp tools, when it's right, it's right.

    Here's an example of a simple event tracking system where the object being tracked needs not pass a creator that it
    doesn't need itself along:

        module Current
          thread_mattr_accessor :account
          thread_mattr_accessor :user

          def self.reset() self.account = self.user = nil end
        end

        class ApplicationController < ActionController::Base
          before_action :set_current
          after_action { Current.reset }

          private
            def set_current
              Current.account = Account.find(params[:account_id])
              Current.user    = Current.account.users.find(params[:user_id])
            end
        end

        class MessagesController < ApplicationController
          def create
            @message = Message.create!(message_params)
          end
        end

        class Message < ApplicationRecord
          has_many :events
          after_create :track_created

          private
            def track_created
              events.create! origin: self, action: :create
            end
        end

        class Event < ApplicationRecord
          belongs_to :creator, class_name: 'User'
          before_validation { self.creator ||= Current.user }
        end

    *DHH*


*   Deprecated `Module#qualified_const_` in favour of the builtin Module#const_
    methods.

    *Genadi Samokovarov*

*   Deprecate passing string to define callback.

    *Yuichiro Kaneko*

*   `ActiveSupport::Cache::Store#namespaced_key`,
    `ActiveSupport::Cache::MemCachedStore#escape_key`, and
    `ActiveSupport::Cache::FileStore#key_file_path`
    are deprecated and replaced with `normalize_key` that now calls `super`.

    `ActiveSupport::Cache::LocaleCache#set_cache_value` is deprecated and replaced with `write_cache_value`.

    *Michael Grosser*

*   Implements an evented file watcher to asynchronously detect changes in the
    application source code, routes, locales, etc.

    This watcher is disabled by default, applications my enable it in the configuration:

        # config/environments/development.rb
        config.file_watcher = ActiveSupport::EventedFileUpdateChecker

    This feature depends on the [listen](https://github.com/guard/listen) gem:

        group :development do
          gem 'listen', '~> 3.0.5'
        end

    *Puneet Agarwal* and *Xavier Noria*

*   Added `Time.days_in_year` to return the number of days in the given year, or the
    current year if no argument is provided.

    *Jon Pascoe*

*   Updated `parameterize` to preserve the case of a string, optionally.

    Example:

        parameterize("Donald E. Knuth", separator: '_') # => "donald_e_knuth"
        parameterize("Donald E. Knuth", preserve_case: true) # => "Donald-E-Knuth"

    *Swaathi Kakarla*

*   `HashWithIndifferentAccess.new` respects the default value or proc on objects
    that respond to `#to_hash`. `.new_from_hash_copying_default` simply invokes `.new`.
    All calls to `.new_from_hash_copying_default` are replaced with `.new`.

    *Gordon Chan*

*   Change Integer#year to return a Fixnum instead of a Float to improve
    consistency.

    Integer#years returned a Float while the rest of the accompanying methods
    (days, weeks, months, etc.) return a Fixnum.

    Before:

    1.year # => 31557600.0

    After:

    1.year # => 31557600

    *Konstantinos Rousis*

*   Handle invalid UTF-8 strings when HTML escaping.

    Use `ActiveSupport::Multibyte::Unicode.tidy_bytes` to handle invalid UTF-8
    strings in `ERB::Util.unwrapped_html_escape` and `ERB::Util.html_escape_once`.
    Prevents user-entered input passed from a querystring into a form field from
    causing invalid byte sequence errors.

    *Grey Baker*

*   Update `ActiveSupport::Multibyte::Chars#slice!` to return `nil` if the
    arguments are out of bounds, to mirror the behavior of `String#slice!`

    *Gourav Tiwari*

*   Fix `number_to_human` so that 999999999 rounds to "1 Billion" instead of
    "1000 Million".

    *Max Jacobson*

*   Fix `ActiveSupport::Deprecation#deprecate_methods` to report using the
    current deprecator instance, where applicable.

    *Brandon Dunne*

*   `Cache#fetch` instrumentation marks whether it was a `:hit`.

    *Robin Clowers*

*   `assert_difference` and `assert_no_difference` now returns the result of the
    yielded block.

    Example:

      post = assert_difference -> { Post.count }, 1 do
        Post.create
      end

    *Lucas Mazza*

*   Short-circuit `blank?` on date and time values since they are never blank.

    Fixes #21657.

    *Andrew White*

*   Replaced deprecated `ThreadSafe::Cache` with its successor `Concurrent::Map` now that
    the thread_safe gem has been merged into concurrent-ruby.

    *Jerry D'Antonio*

*   Updated Unicode version to 8.0.0

    *Anshul Sharma*

*   `number_to_currency` and `number_with_delimiter` now accept custom `delimiter_pattern` option
     to handle placement of delimiter, to support currency formats like INR

     Example:

        number_to_currency(1230000, delimiter_pattern: /(\d+?)(?=(\d\d)+(\d)(?!\d))/, unit: '₹', format: "%u %n")
        # => '₹ 12,30,000.00'

    *Vipul A M*

*   Deprecate `:prefix` option of `number_to_human_size` with no replacement.

    *Jean Boussier*

*   Fix `TimeWithZone#eql?` to properly handle `TimeWithZone` created from `DateTime`:
        twz = DateTime.now.in_time_zone
        twz.eql?(twz.dup) => true

    Fixes #14178.

    *Roque Pinel*

*   ActiveSupport::HashWithIndifferentAccess `select` and `reject` will now return
    enumerator if called without block.

    Fixes #20095.

    *Bernard Potocki*

*   Removed `ActiveSupport::Concurrency::Latch`, superseded by `Concurrent::CountDownLatch`
    from the concurrent-ruby gem.

    *Jerry D'Antonio*

*   Fix not calling `#default` on `HashWithIndifferentAccess#to_hash` when only
    `default_proc` is set, which could raise.

    *Simon Eskildsen*

*   Fix setting `default_proc` on `HashWithIndifferentAccess#dup`.

    *Simon Eskildsen*

*   Fix a range of values for parameters of the Time#change.

    *Nikolay Kondratyev*

*   Add `Enumerable#pluck` to get the same values from arrays as from ActiveRecord
    associations.

    Fixes #20339.

    *Kevin Deisz*

*   Add a bang version to `ActiveSupport::OrderedOptions` get methods which will raise
    an `KeyError` if the value is `.blank?`.

    Before:

        if (slack_url = Rails.application.secrets.slack_url).present?
          # Do something worthwhile
        else
          # Raise as important secret password is not specified
        end

    After:

        slack_url = Rails.application.secrets.slack_url!

    *Aditya Sanghi*, *Gaurish Sharma*

*   Remove deprecated `Class#superclass_delegating_accessor`.
    Use `Class#class_attribute` instead.

    *Akshay Vishnoi*

*   Patch `Delegator` to work with `#try`.

    Fixes #5790.

    *Nate Smith*

*   Add `Integer#positive?` and `Integer#negative?` query methods
    in the vein of `Fixnum#zero?`.

    This makes it nicer to do things like `bunch_of_numbers.select(&:positive?)`.

    *DHH*

*   Encoding `ActiveSupport::TimeWithZone` to YAML now preserves the timezone information.

    Fixes #9183.

    *Andrew White*

*   Added `ActiveSupport::TimeZone#strptime` to allow parsing times as if
    from a given timezone.

    *Paul A Jungwirth*

*   `ActiveSupport::Callbacks#skip_callback` now raises an `ArgumentError` if
    an unrecognized callback is removed.

    *Iain Beeston*

*   Added `ActiveSupport::ArrayInquirer` and `Array#inquiry`.

    Wrapping an array in an `ArrayInquirer` gives a friendlier way to check its
    contents:

        variants = ActiveSupport::ArrayInquirer.new([:phone, :tablet])

        variants.phone?    # => true
        variants.tablet?   # => true
        variants.desktop?  # => false

        variants.any?(:phone, :tablet)   # => true
        variants.any?(:phone, :desktop)  # => true
        variants.any?(:desktop, :watch)  # => false

    `Array#inquiry` is a shortcut for wrapping the receiving array in an
    `ArrayInquirer`.

    *George Claghorn*

*   Deprecate `alias_method_chain` in favour of `Module#prepend` introduced in
    Ruby 2.0.

    *Kir Shatrov*

*   Added `#without` on `Enumerable` and `Array` to return a copy of an
    enumerable without the specified elements.

    *Todd Bealmear*

*   Fixed a problem where `String#truncate_words` would get stuck with a complex
    string.

    *Henrik Nygren*

*   Fixed a roundtrip problem with `AS::SafeBuffer` where primitive-like strings
    will be dumped as primitives:

    Before:

        YAML.load ActiveSupport::SafeBuffer.new("Hello").to_yaml  # => "Hello"
        YAML.load ActiveSupport::SafeBuffer.new("true").to_yaml   # => true
        YAML.load ActiveSupport::SafeBuffer.new("false").to_yaml  # => false
        YAML.load ActiveSupport::SafeBuffer.new("1").to_yaml      # => 1
        YAML.load ActiveSupport::SafeBuffer.new("1.1").to_yaml    # => 1.1

    After:

        YAML.load ActiveSupport::SafeBuffer.new("Hello").to_yaml  # => "Hello"
        YAML.load ActiveSupport::SafeBuffer.new("true").to_yaml   # => "true"
        YAML.load ActiveSupport::SafeBuffer.new("false").to_yaml  # => "false"
        YAML.load ActiveSupport::SafeBuffer.new("1").to_yaml      # => "1"
        YAML.load ActiveSupport::SafeBuffer.new("1.1").to_yaml    # => "1.1"

    *Godfrey Chan*

*   Enable `number_to_percentage` to keep the number's precision by allowing
    `:precision` to be `nil`.

    *Jack Xu*

*   `config_accessor` became a private method, as with Ruby's `attr_accessor`.

    *Akira Matsuda*

*   `AS::Testing::TimeHelpers#travel_to` now changes `DateTime.now` as well as
    `Time.now` and `Date.today`.

    *Yuki Nishijima*

*   Add `file_fixture` to `ActiveSupport::TestCase`.
    It provides a simple mechanism to access sample files in your test cases.

    By default file fixtures are stored in `test/fixtures/files`. This can be
    configured per test-case using the `file_fixture_path` class attribute.

    *Yves Senn*

*   Return value of yielded block in `File.atomic_write`.

    *Ian Ker-Seymer*

*   Duplicate frozen array when assigning it to a `HashWithIndifferentAccess` so
    that it doesn't raise a `RuntimeError` when calling `map!` on it in `convert_value`.

    Fixes #18550.

    *Aditya Kapoor*

*   Add missing time zone definitions for Russian Federation and sync them
    with `zone.tab` file from tzdata version 2014j (latest).

    *Andrey Novikov*

*   Add `SecureRandom.base58` for generation of random base58 strings.

    *Matthew Draper*, *Guillermo Iguaran*

*   Add `#prev_day` and `#next_day` counterparts to `#yesterday` and
    `#tomorrow` for `Date`, `Time`, and `DateTime`.

    *George Claghorn*

*   Add `same_time` option to `#next_week` and `#prev_week` for `Date`, `Time`,
    and `DateTime`.

    *George Claghorn*

*   Add `#on_weekend?`, `#next_weekday`, `#prev_weekday` methods to `Date`,
    `Time`, and `DateTime`.

    `#on_weekend?` returns `true` if the receiving date/time falls on a Saturday
    or Sunday.

    `#next_weekday` returns a new date/time representing the next day that does
    not fall on a Saturday or Sunday.

    `#prev_weekday` returns a new date/time representing the previous day that
    does not fall on a Saturday or Sunday.

    *George Claghorn*

*   Added ability to `TaggedLogging` to allow loggers to be instantiated multiple times
    so that they don't share tags with each other.

        Rails.logger = Logger.new(STDOUT)

        # Before
        custom_logger = ActiveSupport::TaggedLogging.new(Rails.logger)
        custom_logger.push_tags "custom_tag"
        custom_logger.info "test"  # => "[custom_tag] [custom_tag] test"
        Rails.logger.info "test"   # => "[custom_tag] [custom_tag] test"

        # After
        custom_logger = ActiveSupport::TaggedLogging.new(Logger.new(STDOUT))
        custom_logger.push_tags "custom_tag"
        custom_logger.info "test"  # => "[custom_tag] test"
        Rails.logger.info "test"   # => "test"

    *Alexander Staubo*

*   Change the default test order from `:sorted` to `:random`.

    *Rafael Mendonça França*

*   Remove deprecated `ActiveSupport::JSON::Encoding::CircularReferenceError`.

    *Rafael Mendonça França*

*   Remove deprecated methods `ActiveSupport::JSON::Encoding.encode_big_decimal_as_string=`
    and `ActiveSupport::JSON::Encoding.encode_big_decimal_as_string`.

    *Rafael Mendonça França*

*   Remove deprecated `ActiveSupport::SafeBuffer#prepend`.

    *Rafael Mendonça França*

*   Remove deprecated methods at `Kernel`.

    `silence_stderr`, `silence_stream`, `capture` and `quietly`.

    *Rafael Mendonça França*

*   Remove deprecated `active_support/core_ext/big_decimal/yaml_conversions`
    file.

    *Rafael Mendonça França*

*   Remove deprecated methods `ActiveSupport::Cache::Store.instrument` and
    `ActiveSupport::Cache::Store.instrument=`.

    *Rafael Mendonça França*

*   Change the way in which callback chains can be halted.

    The preferred method to halt a callback chain from now on is to explicitly
    `throw(:abort)`.
    In the past, callbacks could only be halted by explicitly providing a
    terminator and by having a callback match the conditions of the terminator.

*   Add `ActiveSupport.halt_callback_chains_on_return_false`

    Setting `ActiveSupport.halt_callback_chains_on_return_false`
    to `true` will let an app support the deprecated way of halting Active Record,
    and Active Model callback chains by returning `false`.

    Setting the value to `false` will tell the app to ignore any `false` value
    returned by those callbacks, and only halt the chain upon `throw(:abort)`.

    When the configuration option is missing, its value is `true`, so older apps
    ported to Rails 5.0 will not break (but display a deprecation warning).
    For new Rails 5.0 apps, its value is set to `false` in an initializer, so
    these apps will support the new behavior by default.

    *claudiob*, *Roque Pinel*

*   Changes arguments and default value of CallbackChain's `:terminator` option

    Chains of callbacks defined without an explicit `:terminator` option will
    now be halted as soon as a `before_` callback throws `:abort`.

    Chains of callbacks defined with a `:terminator` option will maintain their
    existing behavior of halting as soon as a `before_` callback matches the
    terminator's expectation.

    *claudiob*

*   Deprecate `MissingSourceFile` in favor of `LoadError`.

    `MissingSourceFile` was just an alias to `LoadError` and was not being
    raised inside the framework.

    *Rafael Mendonça França*

*   Remove `Object#itself` as it is implemented in Ruby 2.2.

    *Cristian Bica*

*   Add support for error dispatcher classes in `ActiveSupport::Rescuable`.
    Now it acts closer to Ruby's rescue.

    Example:

        class BaseController < ApplicationController
          module ErrorDispatcher
            def self.===(other)
              Exception === other && other.respond_to?(:status)
            end
          end

          rescue_from ErrorDispatcher do |error|
            render status: error.status, json: { error: error.to_s }
          end
        end

    *Genadi Samokovarov*

*   Add `#verified` and `#valid_message?` methods to `ActiveSupport::MessageVerifier`

    Previously, the only way to decode a message with `ActiveSupport::MessageVerifier`
    was to use `#verify`, which would raise an exception on invalid messages. Now
    `#verified` can also be used, which returns `nil` on messages that cannot be
    decoded.

    Previously, there was no way to check if a message's format was valid without
    attempting to decode it. `#valid_message?` is a boolean convenience method that
    checks whether the message is valid without actually decoding it.

    *Logan Leger*

Please check [4-2-stable](https://github.com/rails/rails/blob/4-2-stable/activesupport/CHANGELOG.md) for previous changes.
