## Rails 4.1.14.2 (February 26, 2016) ##

*   No changes.


## Rails 4.1.14.1 (January 25, 2015) ##

*   No changes.


## Rails 4.1.14 (November 12, 2015) ##

*   No changes.


## Rails 4.1.13 (August 24, 2015) ##

*   No changes.


## Rails 4.1.12 (June 25, 2015) ##

*   No changes.


## Rails 4.1.11 (June 16, 2015) ##

*   Fix XSS vulnerability in `ActiveSupport::JSON.encode` method.

    CVE-2015-3226.

    *Rafael Mendonça França*

*   Fix denial of service vulnerability in the XML processing.

    CVE-2015-3227.

    *Aaron Patterson*


## Rails 4.1.10 (March 19, 2015) ##

*   Fixed a roundtrip problem with AS::SafeBuffer where primitive-like strings
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

*   Replace fixed `:en` with `I18n.default_locale` in `Duration#inspect`.

    *Dominik Masur*

*   Add missing time zone definitions for Russian Federation and sync them
    with `zone.tab` file from tzdata version 2014j (latest).

    *Andrey Novikov*


## Rails 4.1.9 (January 6, 2015) ##

*   No changes.


## Rails 4.1.8 (November 16, 2014) ##

*   `Method` objects now report themselves as not `duplicable?`. This allows
    hashes and arrays containing `Method` objects to be `deep_dup`ed.

    *Peter Jaros*


## Rails 4.1.7.1 (November 19, 2014) ##

*   No changes.


## Rails 4.1.7 (October 29, 2014) ##

*   No changes.


## Rails 4.1.6 (September 11, 2014) ##

*   Fix DateTime comparison with DateTime::Infinity object.

    *Rafael Mendonça França*

*   Fixed a compatibility issue with the `Oj` gem when cherry-picking the file
    `active_support/core_ext/object/json` without requiring `active_support/json`.

    Fixes #16131.

    *Godfrey Chan*

*   Make Dependencies pass a name to NameError error.

    *arthurnn*, *Yuki Nishijima*

*   Fixed precision error in NumberHelper when using Rationals.

    before:
        ActiveSupport::NumberHelper.number_to_rounded Rational(1000, 3), precision: 2
        #=> "330.00"
    after:
        ActiveSupport::NumberHelper.number_to_rounded Rational(1000, 3), precision: 2
        #=> "333.33"

    See #15379.

    *Juanjo Bazán*


## Rails 4.1.5 (August 18, 2014) ##

*   No changes.


## Rails 4.1.4 (July 2, 2014) ##

*   No changes.


## Rails 4.1.3 (July 2, 2014) ##

*   No changes.


## Rails 4.1.2 (June 26, 2014) ##

*   `Hash#deep_transform_keys` and `Hash#deep_transform_keys!` now transform hashes
    in nested arrays.  This change also applies to `Hash#deep_stringify_keys`,
    `Hash#deep_stringify_keys!`, `Hash#deep_symbolize_keys` and
    `Hash#deep_symbolize_keys!`.

    *OZAWA Sakuro*

*   Fixed `ActiveSupport::Subscriber` so that no duplicate subscriber is created
    when a subscriber method is redefined.

    *Dennis Schön*

*   Fixed an issue when using
    `ActiveSupport::NumberHelper::NumberToDelimitedConverter` to
    convert a value that is an `ActiveSupport::SafeBuffer` introduced
    in 2da9d67.

    For more info see #15064.

    *Mark J. Titorenko*

*   Fixed backward compatibility isues introduced in 326e652.

    Empty Hash or Array should not present in serialization result.

        {a: []}.to_query # => ""
        {a: {}}.to_query # => ""

    For more info see #14948.

    *Bogdan Gusiev*
*   Fixed `ActiveSupport::Duration#eql?` so that `1.second.eql?(1.second)` is
    true.

    This fixes the current situation of:

        1.second.eql?(1.second) #=> false

    `eql?` also requires that the other object is an `ActiveSupport::Duration`.
    This requirement makes `ActiveSupport::Duration`'s behavior consistent with
    the behavior of Ruby's numeric types:

        1.eql?(1.0) #=> false
        1.0.eql?(1) #=> false

        1.second.eql?(1) #=> false (was true)
        1.eql?(1.second) #=> false

        { 1 => "foo", 1.0 => "bar" }
        #=> { 1 => "foo", 1.0 => "bar" }

        { 1 => "foo", 1.second => "bar" }
        # now => { 1 => "foo", 1.second => "bar" }
        # was => { 1 => "bar" }

    And though the behavior of these hasn't changed, for reference:

        1 == 1.0 #=> true
        1.0 == 1 #=> true

        1 == 1.second #=> true
        1.second == 1 #=> true

    *Emily Dobervich*

*   `ActiveSupport::SafeBuffer#prepend` acts like `String#prepend` and modifies
    instance in-place, returning self. `ActiveSupport::SafeBuffer#prepend!` is
    deprecated.

    *Pavel Pravosud*

*   `HashWithIndifferentAccess` better respects `#to_hash` on objects it's
    given. In particular `#update`, `#merge`, `#replace` all accept objects
    which respond to `#to_hash`, even if those objects are not Hashes directly.

    Currently, if `HashWithIndifferentAccess.new` is given a non-Hash (even if
    it responds to `#to_hash`) that object is treated as the default value,
    rather than the initial keys and value. Changing that could break existing
    code, so it will be updated in the next minor version.

    *Peter Jaros*


## Rails 4.1.1 (May 6, 2014) ##

*   No changes.


## Rails 4.1.0 (April 8, 2014) ##

*   Added `Object#presence_in` to simplify value whitelisting.

    Before:

        params[:bucket_type].in?(%w( project calendar )) ? params[:bucket_type] : nil

    After:

        params[:bucket_type].presence_in %w( project calendar )

    *DHH*

*   Time helpers honor the application time zone when passed a date.

    *Xavier Noria*

*   Fix the implementation of Multibyte::Unicode.tidy_bytes for JRuby

    The existing implementation caused JRuby to raise the error:
    `Encoding::ConverterNotFoundError: code converter not found (UTF-8 to UTF8-MAC)`

    *Justin Coyne*

*   Fix `to_param` behavior when there are nested empty hashes.

    Before:

        params = {c: 3, d: {}}.to_param # => "&c=3"

    After:

        params = {c: 3, d: {}}.to_param # => "c=3&d="

    Fixes #13892.

    *Hincu Petru*

*   Deprecate custom `BigDecimal` serialization.

    Deprecate the custom `BigDecimal` serialization that is included when requiring
    `active_support/all`. Let Ruby handle YAML serialization for `BigDecimal`
    instead.

    Fixes #12467.

    *David Celis*

*   Fix parsing bugs in `XmlMini`

    Symbols or boolean parsing would raise an error for non string values (e.g.
    integers). Decimal parsing would fail due to a missing requirement.

    *Birkir A. Barkarson*

*   Maintain the current timezone when calling `wrap_with_time_zone`

    Extend the solution from the fix for #12163 to the general case where `Time`
    methods are wrapped with a time zone.

    Fixes #12596.

    *Andrew White*

*   Remove behavior that automatically remove the Date/Time stubs, added by `travel`
    and `travel_to` methods, after each test case.

    Now users have to use the `travel_back` or the block version of `travel` and
    `travel_to` methods to clean the stubs.

    *Rafael Mendonça França*

*   Add `travel_back` to remove stubs from `travel` and `travel_to`.

    *Rafael Mendonça França*

*   Remove the deprecation about the `#filter` method.

    Filter objects should now rely on method corresponding to the filter type
    (e.g. `#before`).

    *Aaron Patterson*

*   Add `ActiveSupport::JSON::Encoding.time_precision` as a way to configure the
    precision of encoded time values:

        Time.utc(2000, 1, 1).as_json                      # => "2000-01-01T00:00:00.000Z"
        ActiveSupport::JSON::Encoding.time_precision = 0
        Time.utc(2000, 1, 1).as_json                      # => "2000-01-01T00:00:00Z"

    *Parker Selbert*

*   Maintain the current timezone when calling `change` during DST overlap

    Currently if a time is changed during DST overlap in the autumn then the method
    `period_for_local` will return the DST period. However if the original time is
    not DST then this can be surprising and is not what is generally wanted. This
    commit changes that behavior to maintain the current period if it's in the list
    of periods returned by `periods_for_local`.

    Fixes #12163.

    *Andrew White*

*   Added `Hash#compact` and `Hash#compact!` for removing items with nil value
    from hash.

    *Celestino Gomes*

*   Maintain proleptic gregorian in Time#advance

    `Time#advance` uses `Time#to_date` and `Date#advance` to calculate a new date.
    The `Date` object returned by `Time#to_date` is constructed with the assumption
    that the `Time` object represents a proleptic gregorian date, but it is
    configured to observe the default julian calendar reform date (2299161j)
    for purposes of calculating month, date and year:

        Time.new(1582, 10, 4).to_date.to_s           # => "1582-09-24"
        Time.new(1582, 10, 4).to_date.gregorian.to_s # => "1582-10-04"

    This patch ensures that when the intermediate `Date` object is advanced
    to yield a new `Date` object, that the `Time` object for return is constructed
    with a proleptic gregorian month, date and year.

    *Riley Lynch*

*   `MemCacheStore` should only accept a `Dalli::Client`, or create one.

    *arthurnn*

*   Don't lazy load the `tzinfo` library as it causes problems on Windows.

    Fixes #13553.

    *Andrew White*

*   Use `remove_possible_method` instead of `remove_method` to avoid
    a `NameError` to be thrown on FreeBSD with the `Date` object.

    *Rafael Mendonça França*, *Robin Dupret*

*   `blank?` and `present?` commit to return singletons.

    *Xavier Noria*, *Pavel Pravosud*

*   Fixed Float related error in NumberHelper with large precisions.

    Before:

        ActiveSupport::NumberHelper.number_to_rounded '3.14159', precision: 50
        #=> "3.14158999999999988261834005243144929409027099609375"

    After:

        ActiveSupport::NumberHelper.number_to_rounded '3.14159', precision: 50
        #=> "3.14159000000000000000000000000000000000000000000000"

    *Kenta Murata*, *Akira Matsuda*

*   Default the new `I18n.enforce_available_locales` config to `true`, meaning
    `I18n` will make sure that all locales passed to it must be declared in the
    `available_locales` list.

    To disable it add the following configuration to your application:

        config.i18n.enforce_available_locales = false

    This also ensures I18n configuration is properly initialized taking the new
    option into account, to avoid their deprecations while booting up the app.

    *Carlos Antonio da Silva*, *Yves Senn*

*   Introduce Module#concerning: a natural, low-ceremony way to separate
    responsibilities within a class.

    Imported from https://github.com/37signals/concerning#readme

        class Todo < ActiveRecord::Base
          concerning :EventTracking do
            included do
              has_many :events
            end

            def latest_event
              ...
            end

            private
              def some_internal_method
                ...
              end
          end

          concerning :Trashable do
            def trashed?
              ...
            end

            def latest_event
              super some_option: true
            end
          end
        end

    is equivalent to defining these modules inline, extending them into
    concerns, then mixing them in to the class.

    Inline concerns tame "junk drawer" classes that intersperse many unrelated
    class-level declarations, public instance methods, and private
    implementation. Coalesce related bits and give them definition.
    These are a stepping stone toward future growth & refactoring.

    When to move on from an inline concern:
     * Encapsulating state? Extract collaborator object.
     * Encompassing more public behavior or implementation? Move to separate file.
     * Sharing behavior among classes? Move to separate file.

    *Jeremy Kemper*

*   Fix file descriptor being leaked on each call to `Kernel.silence_stream`.

    *Mario Visic*

*   Added `Date#all_week/month/quarter/year` for generating date ranges.

    *Dmitriy Meremyanin*

*   Add `Time.zone.yesterday` and `Time.zone.tomorrow`. These follow the
    behavior of Ruby's `Date.yesterday` and `Date.tomorrow` but return localized
    versions, similar to how `Time.zone.today` has returned a localized version
    of `Date.today`.

    *Colin Bartlett*

*   Show valid keys when `assert_valid_keys` raises an exception, and show the
    wrong value as it was entered.

    *Gonzalo Rodríguez-Baltanás Díaz*

*   Deprecated `Numeric#{ago,until,since,from_now}`, the user is expected to explicitly
    convert the value into an AS::Duration, i.e. `5.ago` => `5.seconds.ago`

    This will help to catch subtle bugs like:

        def recent?(days = 3)
          self.created_at >= days.ago
        end

    The above code would check if the model is created within the last 3 **seconds**.

    In the future, `Numeric#{ago,until,since,from_now}` should be removed completely,
    or throw some sort of errors to indicate there are no implicit conversion from
    Numeric to AS::Duration.

    *Godfrey Chan*

*   Requires JSON gem version 1.7.7 or above due to a security issue in older versions.

    *Godfrey Chan*

*   Removed the old pure-Ruby JSON encoder and switched to a new encoder based on the built-in JSON
    gem.

    Support for encoding `BigDecimal` as a JSON number, as well as defining custom `encode_json`
    methods to control the JSON output has been **removed from core**. The new encoder will always
    encode BigDecimals as `String`s and ignore any custom `encode_json` methods.

    The old encoder has been extracted into the `activesupport-json_encoder` gem. Installing that
    gem will bring back the ability to encode `BigDecimal`s as numbers as well as `encode_json`
    support.

    Setting the related configuration `ActiveSupport.encode_big_decimal_as_string` without the
    `activesupport-json_encoder` gem installed will raise an error.

    *Godfrey Chan*

*   Add `ActiveSupport::Testing::TimeHelpers#travel` and `#travel_to`. These methods change current
    time to the given time or time difference by stubbing `Time.now` and `Date.today` to return the
    time or date after the difference calculation, or the time or date that got passed into the
    method respectively.

    Example for `#travel`:

        Time.now # => 2013-11-09 15:34:49 -05:00
        travel 1.day
        Time.now # => 2013-11-10 15:34:49 -05:00
        Date.today # => Sun, 10 Nov 2013

    Example for `#travel_to`:

        Time.now # => 2013-11-09 15:34:49 -05:00
        travel_to Time.new(2004, 11, 24, 01, 04, 44)
        Time.now # => 2004-11-24 01:04:44 -05:00
        Date.today # => Wed, 24 Nov 2004

    Both of these methods also accept a block, which will return the current time back to its
    original state at the end of the block:

        Time.now # => 2013-11-09 15:34:49 -05:00

        travel 1.day do
          User.create.created_at # => Sun, 10 Nov 2013 15:34:49 EST -05:00
        end

        travel_to Time.new(2004, 11, 24, 01, 04, 44) do
          User.create.created_at # => Wed, 24 Nov 2004 01:04:44 EST -05:00
        end

        Time.now # => 2013-11-09 15:34:49 -05:00

    This module is included in `ActiveSupport::TestCase` automatically.

    *Prem Sichanugrist*, *DHH*

*   Unify `cattr_*` interface: allow to pass a block to `cattr_reader`.

    Example:

        class A
          cattr_reader(:defr) { 'default_reader_value' }
        end
        A.defr # => 'default_reader_value'

    *Alexey Chernenkov*

*   Improved compatibility with the stdlib JSON gem.

    Previously, calling `::JSON.{generate,dump}` sometimes causes unexpected
    failures such as intridea/multi_json#86.

    `::JSON.{generate,dump}` now bypasses the ActiveSupport JSON encoder
    completely and yields the same result with or without ActiveSupport. This
    means that it will **not** call `as_json` and will ignore any options that
    the JSON gem does not natively understand. To invoke ActiveSupport's JSON
    encoder instead, use `obj.to_json(options)` or
    `ActiveSupport::JSON.encode(obj, options)`.

    *Godfrey Chan*

*   Fix Active Support `Time#to_json` and `DateTime#to_json` to return 3 decimal
    places worth of fractional seconds, similar to `TimeWithZone`.

    *Ryan Glover*

*   Removed circular reference protection in JSON encoder, deprecated
    `ActiveSupport::JSON::Encoding::CircularReferenceError`.

    *Godfrey Chan*, *Sergio Campamá*

*   Add `capitalize` option to `Inflector.humanize`, so strings can be humanized without being capitalized:

        'employee_salary'.humanize                    # => "Employee salary"
        'employee_salary'.humanize(capitalize: false) # => "employee salary"

    *claudiob*

*   Fixed `Object#as_json` and `Struct#as_json` not working properly with options. They now take
    the same options as `Hash#as_json`:

        struct = Struct.new(:foo, :bar).new
        struct.foo = "hello"
        struct.bar = "world"
        json = struct.as_json(only: [:foo]) # => {foo: "hello"}

    *Sergio Campamá*, *Godfrey Chan*

*   Added `Numeric#in_milliseconds`, like `1.hour.in_milliseconds`, so we can feed them to JavaScript functions like `getTime()`.

    *DHH*

*   Calling `ActiveSupport::JSON.decode` with unsupported options now raises an error.

    *Godfrey Chan*

*   Support `:unless_exist` in `FileStore`.

    *Michael Grosser*

*   Fix `slice!` deleting the default value of the hash.

    *Antonio Santos*

*   `require_dependency` accepts objects that respond to `to_path`, in
    particular `Pathname` instances.

    *Benjamin Fleischer*

*   Disable the ability to iterate over Range of AS::TimeWithZone
    due to significant performance issues.

    *Bogdan Gusiev*

*   Allow attaching event subscribers to ActiveSupport::Notifications namespaces
    before they're defined. Essentially, this means instead of this:

        class JokeSubscriber < ActiveSupport::Subscriber
          def sql(event)
            puts "A rabbi and a priest walk into a bar..."
          end

          # This call needs to happen *after* defining the methods.
          attach_to "active_record"
        end

    You can do this:

        class JokeSubscriber < ActiveSupport::Subscriber
          # This is much easier to read!
          attach_to "active_record"

          def sql(event)
            puts "A rabbi and a priest walk into a bar..."
          end
        end

    This should make it easier to read and understand these subscribers.

    *Daniel Schierbeck*

*   Add `Date#middle_of_day`, `DateTime#middle_of_day` and `Time#middle_of_day` methods.

    Also added `midday`, `noon`, `at_midday`, `at_noon` and `at_middle_of_day` as aliases.

    *Anatoli Makarevich*

*   Fix ActiveSupport::Cache::FileStore#cleanup to no longer rely on missing each_key method.

    *Murray Steele*

*   Ensure that autoloaded constants in all-caps nestings are marked as
    autoloaded.

    *Simon Coffey*

*   Add `String#remove(pattern)` as a short-hand for the common pattern of
    `String#gsub(pattern, '')`.

    *DHH*

*   Adds a new deprecation behaviour that raises an exception. Throwing this
    line into +config/environments/development.rb+

        ActiveSupport::Deprecation.behavior = :raise

    will cause the application to raise an +ActiveSupport::DeprecationException+
    on deprecations.

    Use this for aggressive deprecation cleanups.

    *Xavier Noria*

*   Remove 'cow' => 'kine' irregular inflection from default inflections.

    *Andrew White*

*   Add `DateTime#to_s(:iso8601)` and `Date#to_s(:iso8601)` for consistency.

    *Andrew White*

*   Add `Time#to_s(:iso8601)` for easy conversion of times to the iso8601 format for easy Javascript date parsing.

    *DHH*

*   Improve `ActiveSupport::Cache::MemoryStore` cache size calculation.
    The memory used by a key/entry pair is calculated via `#cached_size`:

        def cached_size(key, entry)
          key.to_s.bytesize + entry.size + PER_ENTRY_OVERHEAD
        end

    The value of `PER_ENTRY_OVERHEAD` is 240 bytes based on an [empirical
    estimation](https://gist.github.com/ssimeonov/6047200) for 64-bit MRI on
    1.9.3 and 2.0.

    Fixes #11512.

    *Simeon Simeonov*

*   Only raise `Module::DelegationError` if it's the source of the exception.

    Fixes #10559.

    *Andrew White*

*   Make `Time.at_with_coercion` retain the second fraction and return local time.

    Fixes #11350.

    *Neer Friedman*, *Andrew White*

*   Make `HashWithIndifferentAccess#select` always return the hash, even when
    `Hash#select!` returns `nil`, to allow further chaining.

    *Marc Schütz*

*   Remove deprecated `String#encoding_aware?` core extensions (`core_ext/string/encoding`).

    *Arun Agrawal*

*   Remove deprecated `Module#local_constant_names` in favor of `Module#local_constants`.

    *Arun Agrawal*

*   Remove deprecated `DateTime.local_offset` in favor of `DateTime.civil_from_format`.

    *Arun Agrawal*

*   Remove deprecated `Logger` core extensions (`core_ext/logger.rb`).

    *Carlos Antonio da Silva*

*   Remove deprecated `Time#time_with_datetime_fallback`, `Time#utc_time`
    and `Time#local_time` in favor of `Time#utc` and `Time#local`.

    *Vipul A M*

*   Remove deprecated `Hash#diff` with no replacement.

    If you're using it to compare hashes for the purpose of testing, please use
    MiniTest's `assert_equal` instead.

    *Carlos Antonio da Silva*

*   Remove deprecated `Date#to_time_in_current_zone` in favor of `Date#in_time_zone`.

    *Vipul A M*

*   Remove deprecated `Proc#bind` with no replacement.

    *Carlos Antonio da Silva*

*   Remove deprecated `Array#uniq_by` and `Array#uniq_by!`, use native
    `Array#uniq` and `Array#uniq!` instead.

    *Carlos Antonio da Silva*

*   Remove deprecated `ActiveSupport::BasicObject`, use `ActiveSupport::ProxyObject` instead.

    *Carlos Antonio da Silva*

*   Remove deprecated `BufferedLogger`, use `ActiveSupport::Logger` instead.

    *Yves Senn*

*   Remove deprecated `assert_present` and `assert_blank` methods, use `assert
    object.blank?` and `assert object.present?` instead.

    *Yves Senn*

*   Fix return value from `BacktraceCleaner#noise` when the cleaner is configured
    with multiple silencers.

    Fixes #11030.

    *Mark J. Titorenko*

*   `HashWithIndifferentAccess#select` now returns a `HashWithIndifferentAccess`
    instance instead of a `Hash` instance.

    Fixes #10723.

    *Albert Llop*

*   Add `DateTime#usec` and `DateTime#nsec` so that `ActiveSupport::TimeWithZone` keeps
    sub-second resolution when wrapping a `DateTime` value.

    Fixes #10855.

    *Andrew White*

*   Fix `ActiveSupport::Dependencies::Loadable#load_dependency` calling
    `#blame_file!` on Exceptions that do not have the Blamable mixin

    *Andrew Kreiling*

*   Override `Time.at` to support the passing of Time-like values when called with a single argument.

    *Andrew White*

*   Prevent side effects to hashes inside arrays when
    `Hash#with_indifferent_access` is called.

    Fixes #10526.

    *Yves Senn*

*   Removed deprecated `ActiveSupport::JSON::Variable` with no replacement.

    *Toshinori Kajihara*

*   Raise an error when multiple `included` blocks are defined for a Concern.
    The old behavior would silently discard previously defined blocks, running
    only the last one.

    *Mike Dillon*

*   Replace `multi_json` with `json`.

    Since Rails requires Ruby 1.9 and since Ruby 1.9 includes `json` in the standard library,
    `multi_json` is no longer necessary.

    *Erik Michaels-Ober*

*   Added escaping of U+2028 and U+2029 inside the json encoder.
    These characters are legal in JSON but break the Javascript interpreter.
    After escaping them, the JSON is still legal and can be parsed by Javascript.

    *Mario Caropreso + Viktor Kelemen + zackham*

*   Fix skipping object callbacks using metadata fetched via callback chain
    inspection methods (`_*_callbacks`)

    *Sean Walbran*

*   Add a `fetch_multi` method to the cache stores. The method provides
    an easy to use API for fetching multiple values from the cache.

    Example:

        # Calculating scores is expensive, so we only do it for posts
        # that have been updated. Cache keys are automatically extracted
        # from objects that define a #cache_key method.
        scores = Rails.cache.fetch_multi(*posts) do |post|
          calculate_score(post)
        end

    *Daniel Schierbeck*

Please check [4-0-stable](https://github.com/rails/rails/blob/4-0-stable/activesupport/CHANGELOG.md) for previous changes.
