## Rails 5.1.2 (June 26, 2017) ##

*   Cache: Restore the `options = nil` argument for `LocalStore#clear`
    that was removed in 5.1.0. Restores compatibility with backends that
    take an options argument and use the local cache strategy.

    *Jeremy Daer*

*   Fix implicit coercion calculations with scalars and durations

    Previously calculations where the scalar is first would be converted to a duration
    of seconds but this causes issues with dates being converted to times, e.g:

        Time.zone = "Beijing"           # => Asia/Shanghai
        date = Date.civil(2017, 5, 20)  # => Mon, 20 May 2017
        2 * 1.day                       # => 172800 seconds
        date + 2 * 1.day                # => Mon, 22 May 2017 00:00:00 CST +08:00

    Now the `ActiveSupport::Duration::Scalar` calculation methods will try to maintain
    the part structure of the duration where possible, e.g:

        Time.zone = "Beijing"           # => Asia/Shanghai
        date = Date.civil(2017, 5, 20)  # => Mon, 20 May 2017
        2 * 1.day                       # => 2 days
        date + 2 * 1.day                # => Mon, 22 May 2017

    Fixes #29160, #28970.

    *Andrew White*


## Rails 5.1.1 (May 12, 2017) ##

*   No changes.


## Rails 5.1.0 (April 27, 2017) ##

*   `ActiveSupport::EventedFileUpdateChecker` no longer listens to
    directories outside of the application directory.

    *radiospiel*

*   Return unmapped timezones from `country_zones`

    If a country doesn't exist in the MAPPINGS hash then create a new
    `ActiveSupport::Timezone` instance using the supplied timezone id.

    Fixes #28431.

    *Andrew White*

*   Add ActiveSupport::Deprecation::DeprecatedConstantAccessor

    Provides transparent deprecation of constants, compatible with exceptions.
    Example usage:

        module Example
          include ActiveSupport::Deprecation::DeprecatedConstantAccessor
          deprecate_constant 'OldException', 'Elsewhere::NewException'
        end

    *Dominic Cleal*

*   Fixed bug in `DateAndTime::Compatibility#to_time` that caused it to
    raise `RuntimeError: can't modify frozen Time` when called on any frozen `Time`.
    Properly pass through the frozen `Time` or `ActiveSupport::TimeWithZone` object
    when calling `#to_time`.

    *Kevin McPhillips* & *Andrew White*

*   Remove implicit coercion deprecation of durations

    In #28204 we deprecated implicit conversion of durations to a numeric which
    represented the number of seconds in the duration because of unwanted side
    effects with calculations on durations and dates. This unfortunately had
    the side effect of forcing a explicit cast when configuring third-party
    libraries like expiration in Redis, e.g:

        redis.expire("foo", 5.minutes)

    To work around this we've removed the deprecation and added a private class
    that wraps the numeric and can perform calculation involving durations and
    ensure that they remain a duration irrespective of the order of operations.

    *Andrew White*

*   Update `titleize` regex to allow apostrophes

    In 4b685aa the regex in `titleize` was updated to not match apostrophes to
    better reflect the nature of the transformation. Unfortunately, this had the
    side effect of breaking capitalization on the first word of a sub-string, e.g:

        >> "This was 'fake news'".titleize
        => "This Was 'fake News'"

    This is fixed by extending the look-behind to also check for a word
    character on the other side of the apostrophe.

    Fixes #28312.

    *Andrew White*

*   Add `rfc3339` aliases to `xmlschema` for `Time` and `ActiveSupport::TimeWithZone`

    For naming consistency when using the RFC 3339 profile of ISO 8601 in applications.

    *Andrew White*

*   Add `Time.rfc3339` parsing method

    `Time.xmlschema` and consequently its alias `iso8601` accepts timestamps
    without a offset in contravention of the RFC 3339 standard. This method
    enforces that constraint and raises an `ArgumentError` if it doesn't.

    *Andrew White*

*   Add `ActiveSupport::TimeZone.rfc3339` parsing method

    Previously, there was no way to get a RFC 3339 timestamp into a specific
    timezone without either using `parse` or chaining methods. The new method
    allows parsing directly into the timezone, e.g:

        >> Time.zone = "Hawaii"
        => "Hawaii"
        >> Time.zone.rfc3339("1999-12-31T14:00:00Z")
        => Fri, 31 Dec 1999 14:00:00 HST -10:00

    This new method has stricter semantics than the current `parse` method,
    and will raise an `ArgumentError` instead of returning nil, e.g:

        >> Time.zone = "Hawaii"
        => "Hawaii"
        >> Time.zone.rfc3339("foobar")
        ArgumentError: invalid date
        >> Time.zone.parse("foobar")
        => nil

    It will also raise an `ArgumentError` when either the time or offset
    components are missing, e.g:

        >> Time.zone = "Hawaii"
        => "Hawaii"
        >> Time.zone.rfc3339("1999-12-31")
        ArgumentError: invalid date
        >> Time.zone.rfc3339("1999-12-31T14:00:00")
        ArgumentError: invalid date

    *Andrew White*

*   Add `ActiveSupport::TimeZone.iso8601` parsing method

    Previously, there was no way to get a ISO 8601 timestamp into a specific
    timezone without either using `parse` or chaining methods. The new method
    allows parsing directly into the timezone, e.g:

        >> Time.zone = "Hawaii"
        => "Hawaii"
        >> Time.zone.iso8601("1999-12-31T14:00:00Z")
        => Fri, 31 Dec 1999 14:00:00 HST -10:00

    If the timestamp is a ISO 8601 date (YYYY-MM-DD), then the time is set
    to midnight, e.g:

        >> Time.zone = "Hawaii"
        => "Hawaii"
        >> Time.zone.iso8601("1999-12-31")
        => Fri, 31 Dec 1999 00:00:00 HST -10:00

    This new method has stricter semantics than the current `parse` method,
    and will raise an `ArgumentError` instead of returning nil, e.g:

        >> Time.zone = "Hawaii"
        => "Hawaii"
        >> Time.zone.iso8601("foobar")
        ArgumentError: invalid date
        >> Time.zone.parse("foobar")
        => nil

    *Andrew White*

*   Deprecate implicit coercion of `ActiveSupport::Duration`

    Currently `ActiveSupport::Duration` implicitly converts to a seconds
    value when used in a calculation except for the explicit examples of
    addition and subtraction where the duration is the receiver, e.g:

        >> 2 * 1.day
        => 172800

    This results in lots of confusion especially when using durations
    with dates because adding/subtracting a value from a date treats
    integers as a day and not a second, e.g:

        >> Date.today
        => Wed, 01 Mar 2017
        >> Date.today + 2 * 1.day
        => Mon, 10 Apr 2490

    To fix this we're implementing `coerce` so that we can provide a
    deprecation warning with the intent of removing the implicit coercion
    in Rails 5.2, e.g:

        >> 2 * 1.day
        DEPRECATION WARNING: Implicit coercion of ActiveSupport::Duration
        to a Numeric is deprecated and will raise a TypeError in Rails 5.2.
        => 172800

    In Rails 5.2 it will raise `TypeError`, e.g:

        >> 2 * 1.day
        TypeError: ActiveSupport::Duration can't be coerced into Integer

    This is the same behavior as with other types in Ruby, e.g:

        >> 2 * "foo"
        TypeError: String can't be coerced into Integer
        >> "foo" * 2
        => "foofoo"

    As part of this deprecation add `*` and `/` methods to `AS::Duration`
    so that calculations that keep the duration as the receiver work
    correctly whether the final receiver is a `Date` or `Time`, e.g:

        >> Date.today
        => Wed, 01 Mar 2017
        >> Date.today + 1.day * 2
        => Fri, 03 Mar 2017

    Fixes #27457.

    *Andrew White*

*   Update `DateTime#change` to support `:usec` and `:nsec` options.

    Adding support for these options now allows us to update the `DateTime#end_of`
    methods to match the equivalent `Time#end_of` methods, e.g:

        datetime = DateTime.now.end_of_day
        datetime.nsec == 999999999 # => true

    Fixes #21424.

    *Dan Moore*, *Andrew White*

*   Add `ActiveSupport::Duration#before` and `#after` as aliases for `#until` and `#since`

    These read more like English and require less mental gymnastics to read and write.

    Before:

        2.weeks.since(customer_start_date)
        5.days.until(today)

    After:

        2.weeks.after(customer_start_date)
        5.days.before(today)

    *Nick Johnstone*

*   Soft-deprecated the top-level `HashWithIndifferentAccess` constant.
    `ActiveSupport::HashWithIndifferentAccess` should be used instead.

    Fixes #28157.

    *Robin Dupret*

*   In Core Extensions, make `MarshalWithAutoloading#load` pass through the second, optional
    argument for `Marshal#load( source [, proc] )`. This way we don't have to do
    `Marshal.method(:load).super_method.call(source, proc)` just to be able to pass a proc.

    *Jeff Latz*

*   `ActiveSupport::Gzip.decompress` now checks checksum and length in footer.

    *Dylan Thacker-Smith*

*   Cache `ActiveSupport::TimeWithZone#to_datetime` before freezing.

    *Adam Rice*

*   Deprecate `ActiveSupport.halt_callback_chains_on_return_false`.

    *Rafael Mendonça França*

*   Remove deprecated behavior that halts callbacks when the return is false.

    *Rafael Mendonça França*

*   Deprecate passing string to `:if` and `:unless` conditional options
    on `set_callback` and `skip_callback`.

    *Ryuta Kamizono*

*   Raise `ArgumentError` when passing string to define callback.

    *Ryuta Kamizono*

*   Updated Unicode version to 9.0.0

    Now we can handle new emojis such like "👩‍👩‍👧‍👦" ("\u{1F469}\u{200D}\u{1F469}\u{200D}\u{1F467}\u{200D}\u{1F466}").

    version 8.0.0

        "👩‍👩‍👧‍👦".mb_chars.grapheme_length # => 4
        "👩‍👩‍👧‍👦".mb_chars.reverse # => "👦👧‍👩‍👩‍"

    version 9.0.0

        "👩‍👩‍👧‍👦".mb_chars.grapheme_length # => 1
        "👩‍👩‍👧‍👦".mb_chars.reverse # => "👩‍👩‍👧‍👦"

    *Fumiaki MATSUSHIMA*

*   Changed `ActiveSupport::Inflector#transliterate` to raise `ArgumentError` when it receives
    anything except a string.

    *Kevin McPhillips*

*   Fixed bugs that `StringInquirer#respond_to_missing?` and
    `ArrayInquirer#respond_to_missing?` do not fallback to `super`.

    *Akira Matsuda*

*   Fix inconsistent results when parsing large durations and constructing durations from code

        ActiveSupport::Duration.parse('P3Y') == 3.years # It should be true

    Duration parsing made independent from any moment of time:
    Fixed length in seconds is assigned to each duration part during parsing.

    Changed duration of months and years in seconds to more accurate and logical:

     1. The value of 365.2425 days in Gregorian year is more accurate
        as it accounts for every 400th non-leap year.

     2. Month's length is bound to year's duration, which makes
        sensible comparisons like `12.months == 1.year` to be `true`
        and nonsensical ones like `30.days == 1.month` to be `false`.

    Calculations on times and dates with durations shouldn't be affected as
    duration's numeric value isn't used in calculations, only parts are used.

    Methods on `Numeric` like `2.days` now use these predefined durations
    to avoid duplication of duration constants through the codebase and
    eliminate creation of intermediate durations.

    *Andrey Novikov*, *Andrew White*

*   Change return value of `Rational#duplicable?`, `ComplexClass#duplicable?`
    to false.

    *utilum*

*   Change return value of `NilClass#duplicable?`, `FalseClass#duplicable?`,
    `TrueClass#duplicable?`, `Symbol#duplicable?` and `Numeric#duplicable?`
    to true with Ruby 2.4+. These classes can dup with Ruby 2.4+.

    *Yuji Yaginuma*

*   Remove deprecated class `ActiveSupport::Concurrency::Latch`.

    *Andrew White*

*   Remove deprecated separator argument from `parameterize`.

    *Andrew White*

*   Remove deprecated method `Numeric#to_formatted_s`.

    *Andrew White*

*   Remove deprecated method `alias_method_chain`.

    *Andrew White*

*   Remove deprecated constant `MissingSourceFile`.

    *Andrew White*

*   Remove deprecated methods `Module.qualified_const_defined?`,
    `Module.qualified_const_get` and `Module.qualified_const_set`.

    *Andrew White*

*   Remove deprecated `:prefix` option from `number_to_human_size`.

    *Andrew White*

*   Remove deprecated method `ActiveSupport::HashWithIndifferentAccess.new_from_hash_copying_default`.

    *Andrew White*

*   Remove deprecated file `active_support/core_ext/time/marshal.rb`.

    *Andrew White*

*   Remove deprecated file `active_support/core_ext/struct.rb`.

    *Andrew White*

*   Remove deprecated file `active_support/core_ext/module/method_transplanting.rb`.

    *Andrew White*

*   Remove deprecated method `Module.local_constants`.

    *Andrew White*

*   Remove deprecated file `active_support/core_ext/kernel/debugger.rb`.

    *Andrew White*

*   Remove deprecated method `ActiveSupport::Cache::Store#namespaced_key`.

    *Andrew White*

*   Remove deprecated method `ActiveSupport::Cache::Strategy::LocalCache::LocalStore#set_cache_value`.

    *Andrew White*

*   Remove deprecated method `ActiveSupport::Cache::MemCacheStore#escape_key`.

    *Andrew White*

*   Remove deprecated method `ActiveSupport::Cache::FileStore#key_file_path`.

    *Andrew White*

*   Ensure duration parsing is consistent across DST changes.

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

*   Use `Hash#compact` and `Hash#compact!` from Ruby 2.4. Old Ruby versions
    will continue to get these methods from Active Support as before.

    *Prathamesh Sonpatki*

*   Fix `ActiveSupport::TimeZone#strptime`.
    Support for timestamps in format of seconds (%s) and milliseconds (%Q).

    Fixes #26840.

    *Lev Denisov*

*   Fix `DateAndTime::Calculations#copy_time_to`. Copy `nsec` instead of `usec`.

    Jumping forward or backward between weeks now preserves nanosecond digits.

    *Josua Schmid*

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

*   Remove unused parameter `options = nil` for `#clear` of
    `ActiveSupport::Cache::Strategy::LocalCache::LocalStore` and
    `ActiveSupport::Cache::Strategy::LocalCache`.

    *Yosuke Kabuto*

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

*   Defines `Regexp.match?` for Ruby versions prior to 2.4. The predicate
    has the same interface, but it does not have the performance boost. Its
    purpose is to be able to write 2.4 compatible code.

    *Xavier Noria*

*   Allow `MessageEncryptor` to take advantage of authenticated encryption modes.

    AEAD modes like `aes-256-gcm` provide both confidentiality and data
    authenticity, eliminating the need to use `MessageVerifier` to check if the
    encrypted data has been tampered with. This speeds up encryption/decryption
    and results in shorter cipher text.

    *Bart de Water*

*   Introduce `assert_changes` and `assert_no_changes`.

    `assert_changes` is a more general `assert_difference` that works with any
    value.

        assert_changes 'Error.current', from: nil, to: 'ERR' do
          expected_bad_operation
        end

    Can be called with strings, to be evaluated in the binding (context) of
    the block given to the assertion, or a lambda.

        assert_changes -> { Error.current }, from: nil, to: 'ERR' do
          expected_bad_operation
        end

    The `from` and `to` arguments are compared with the case operator (`===`).

        assert_changes 'Error.current', from: nil, to: Error do
          expected_bad_operation
        end

    This is pretty useful, if you need to loosely compare a value. For example,
    you need to test a token has been generated and it has that many random
    characters.

        user = User.start_registration
        assert_changes 'user.token', to: /\w{32}/ do
          user.finish_registration
        end

    *Genadi Samokovarov*

*   Fix `ActiveSupport::TimeZone#strptime`. Now raises `ArgumentError` when the
    given time doesn't match the format. The error is the same as the one given
    by Ruby's `Date.strptime`. Previously it raised
    `NoMethodError: undefined method empty? for nil:NilClass.` due to a bug.

    Fixes #25701.

    *John Gesimondo*

*   `travel/travel_to` travel time helpers, now raise on nested calls,
    as this can lead to confusing time stubbing.

    Instead of:

        travel_to 2.days.from_now do
          # 2 days from today
          travel_to 3.days.from_now do
            # 5 days from today
          end
        end

    preferred way to achieve above is:

        travel 2.days do
          # 2 days from today
        end

        travel 5.days do
          # 5 days from today
        end

    *Vipul A M*

*   Support parsing JSON time in ISO8601 local time strings in
    `ActiveSupport::JSON.decode` when `parse_json_times` is enabled.
    Strings in the format of `YYYY-MM-DD hh:mm:ss` (without a `Z` at
    the end) will be parsed in the local timezone (`Time.zone`). In
    addition, date strings (`YYYY-MM-DD`) are now parsed into `Date`
    objects.

    *Grzegorz Witek*

*   Fixed `ActiveSupport::Logger.broadcast` so that calls to `#silence` now
    properly delegate to all loggers. Silencing now properly suppresses logging
    to both the log and the console.

    *Kevin McPhillips*

*   Remove deprecated arguments in `assert_nothing_raised`.

    *Rafel Mendonça França*

*   `Date.to_s` doesn't produce too many spaces. For example, `to_s(:short)`
    will now produce `01 Feb` instead of ` 1 Feb`.

    Fixes #25251.

    *Sean Griffin*

*   Introduce `Module#delegate_missing_to`.

    When building a decorator, a common pattern emerges:

        class Partition
          def initialize(first_event)
            @events = [ first_event ]
          end

          def people
            if @events.first.detail.people.any?
              @events.collect { |e| Array(e.detail.people) }.flatten.uniq
            else
              @events.collect(&:creator).uniq
            end
          end

          private
            def respond_to_missing?(name, include_private = false)
              @events.respond_to?(name, include_private)
            end

            def method_missing(method, *args, &block)
              @events.send(method, *args, &block)
            end
        end

    With `Module#delegate_missing_to`, the above is condensed to:

        class Partition
          delegate_missing_to :@events

          def initialize(first_event)
            @events = [ first_event ]
          end

          def people
            if @events.first.detail.people.any?
              @events.collect { |e| Array(e.detail.people) }.flatten.uniq
            else
              @events.collect(&:creator).uniq
            end
          end
        end

    *Genadi Samokovarov*, *DHH*

*   Rescuable: If a handler doesn't match the exception, check for handlers
    matching the exception's cause.

    *Jeremy Daer*

Please check [5-0-stable](https://github.com/rails/rails/blob/5-0-stable/activesupport/CHANGELOG.md) for previous changes.
