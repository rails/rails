## Rails 4.0.0 (unreleased) ##

*   Prevent `DateTime#change` from truncating the second fraction, when seconds
    do not need to be changed.

    *Chris Baynes*

*   Added `ActiveSupport::TimeWithZone#to_r` for `Time#at` compatibility.

    Before this change:

        Time.zone = 'Tokyo'
        time = Time.zone.now
        time == Time.at(time) # => false

    After the change:

        Time.zone = 'Tokyo'
        time = Time.zone.now
        time == Time.at(time) # => true

    *stopdropandrew*

*   `ActiveSupport::NumberHelper#number_to_human` returns the number unaltered when
    the given units hash does not contain the needed key, e.g. when the number provided
    is less than the largest key provided.
    Fixes #9269.

    Examples:

        number_to_human(123, units: {}) # => 123
        number_to_human(123, units: { thousand: 'k' }) # => 123

    *Michael Hoffman*

*   Added `beginning_of_minute` support to core ext calculations for `Time` and `DateTime`.

    *Gagan Awhad*

*   Add `:nsec` date format.

    *Jamie Gaskins*

*   `ActiveSupport::Gzip.compress` allows two optional arguments for compression
    level and strategy.

    *Beyond*

*   Modify `TimeWithZone#as_json` to include 3 decimal places of sub-second accuracy
    by default, which is optional as per the ISO8601 spec, but extremely useful. Also
    the default behaviour of `Date#toJSON()` in recent versions of Chrome, Safari and
    Firefox.

    *James Harton*

*   Improve `String#squish` to handle Unicode whitespace. *Antoine Lyset*

*   Standardise on `to_time` returning an instance of `Time` in the local system timezone
    across `String`, `Time`, `Date`, `DateTime` and `ActiveSupport::TimeWithZone`.

    *Andrew White*

*   Extract `ActiveSupport::Testing::Performance` into https://github.com/rails/rails-perftest
    You can add the gem to your `Gemfile` to keep using performance tests.

        gem 'rails-perftest'

    *Yves Senn*

*   `Hash.from_xml` raises when it encounters `type="symbol"` or `type="yaml"`.
    Use `Hash.from_trusted_xml` to parse this XML.

    CVE-2013-0156

    *Jeremy Kemper*

*   Deprecate `assert_present` and `assert_blank` in favor of
    `assert object.blank?` and `assert object.present?`

    *Yves Senn*

*   Change `String#to_date` to use `Date.parse`. This gives more consistent error
    messages and allows the use of partial dates.

        "gibberish".to_date => Argument Error: invalid date
        "3rd Feb".to_date => Sun, 03 Feb 2013

    *Kelly Stannard*

*   It's now possible to compare `Date`, `DateTime`, `Time` and `TimeWithZone`
    with `Float::INFINITY`. This allows to create date/time ranges with one infinite bound.
    Example:

        range = Range.new(Date.today, Float::INFINITY)

    Also it's possible to check inclusion of date/time in range with conversion.

        range.include?(Time.now + 1.year)     # => true
        range.include?(DateTime.now + 1.year) # => true

    *Alexander Grebennik*

*   Remove meaningless `ActiveSupport::FrozenObjectError`, which was just an alias of `RuntimeError`.

    *Akira Matsuda*

*   Introduce `assert_not` to replace warty `assert !foo`.  *Jeremy Kemper*

*   Prevent `Callbacks#set_callback` from setting the same callback twice.

        before_save :foo, :bar, :foo

    will at first call `bar`, then `foo`. `foo` will no more be called
    twice.

    *Dmitriy Kiriyenko*

*   Add `ActiveSupport::Logger#silence` that works the same as the old `Logger#silence` extension.

    *DHH*

*   Remove surrogate unicode character encoding from `ActiveSupport::JSON.encode`
    The encoding scheme was broken for unicode characters outside the basic multilingual plane;
    since json is assumed to be UTF-8, and we already force the encoding to UTF-8,
    simply pass through the un-encoded characters.

    *Brett Carter*

*   Deprecate `Time.time_with_date_fallback`, `Time.utc_time` and `Time.local_time`.
    These methods were added to handle the limited range of Ruby's native `Time`
    implementation. Those limitations no longer apply so we are deprecating them in 4.0
    and they will be removed in 4.1.

    *Andrew White*

*   Deprecate `Date#to_time_in_current_zone` and add `Date#in_time_zone`. *Andrew White*

*   Add `String#in_time_zone` method to convert a string to an `ActiveSupport::TimeWithZone`. *Andrew White*

*   Deprecate `ActiveSupport::BasicObject` in favor of `ActiveSupport::ProxyObject`.
    This class is used for proxy classes. It avoids confusion with Ruby's `BasicObject`
    class.

    *Francesco Rodriguez*

*   Patched `Marshal#load` to work with constant autoloading. Fixes autoloading
    with cache stores that rely on `Marshal` (`MemCacheStore` and `FileStore`).
    Fixes #8167.

    *Uriel Katz*

*   Make `Time.zone.parse` to work with JavaScript format date strings. *Andrew White*

*   Add `DateTime#seconds_until_end_of_day` and `Time#seconds_until_end_of_day`
    as a complement for `seconds_from_midnight`; useful when setting expiration
    times for caches, e.g.:

        <% cache('dashboard', expires_in: Date.current.seconds_until_end_of_day) do %>
          ...

    *Olek Janiszewski*

*   No longer proxy `ActiveSupport::Multibyte#class`. *Steve Klabnik*

*   Deprecate `ActiveSupport::TestCase#pending` method, use `skip` from minitest instead. *Carlos Antonio da Silva*

*   `XmlMini.with_backend` now may be safely used with threads:

        Thread.new do
          XmlMini.with_backend("REXML") { rexml_power }
        end
        Thread.new do
          XmlMini.with_backend("LibXML") { libxml_power }
        end

    Each thread will use it's own backend.

    *Nikita Afanasenko*

*   Dependencies no longer trigger `Kernel#autoload` in `remove_constant`. Fixes #8213. *Xavier Noria*

*   Simplify `mocha` integration and remove monkey-patches, bumping `mocha` to 0.13.0. *James Mead*

*   `#as_json` isolates options when encoding a hash. Fixes #8182.

    *Yves Senn*

*   Deprecate `Hash#diff` in favor of minitest's #diff. *Steve Klabnik*

*   `Kernel#capture` can catch output from subprocesses. *Dmitry Vorotilin*

*   `to_xml` conversions now use builder's `tag!` method instead of explicit invocation of `method_missing`.

    *Nikita Afanasenko*

*   Fixed timezone mapping of the Solomon Islands. *Steve Klabnik*

*   Make callstack attribute optional in `ActiveSupport::Deprecation::Reporting`
    methods `warn` and `deprecation_warning`.

    *Alexey Gaziev*

*   Implement `HashWithIndifferentAccess#replace` so `key?` works correctly. *David Graham*

*   Handle the possible permission denied errors `atomic.rb` might trigger due to its `chown`
    and `chmod` calls.

    *Daniele Sluijters*

*   `Hash#extract!` returns only those keys that present in the receiver.

        {a: 1, b: 2}.extract!(:a, :x) # => {:a => 1}

    *Mikhail Dieterle*

*   `Hash#extract!` returns the same subclass, that the receiver is. I.e.
    `HashWithIndifferentAccess#extract!` returns a `HashWithIndifferentAccess` instance.

    *Mikhail Dieterle*

*   Optimize `ActiveSupport::Cache::Entry` to reduce memory and processing overhead. *Brian Durand*

*   Tests tag the Rails log with the current test class and test case:

        [SessionsControllerTest] [test_0002_sign in] Processing by SessionsController#create as HTML
        [SessionsControllerTest] [test_0002_sign in] ...

    *Jeremy Kemper*

*   Add `logger.push_tags` and `.pop_tags` to complement `logger.tagged`:

        class Job
          def before
            Rails.logger.push_tags :jobs, self.class.name
          end

          def after
            Rails.logger.pop_tags 2
          end
        end

    *Jeremy Kemper*

*   Allow delegation to the class using the `:class` keyword, replacing
    `self.class` usage:

        class User
          def self.hello
           "world"
          end

          delegate :hello, to: :class
        end

    *Marc-Andre Lafortune*

*   `Date.beginning_of_week` thread local and `beginning_of_week` application
    config option added (default is Monday).

    *Innokenty Mikhailov*

*   An optional block can be passed to `config_accessor` to set its default value

        class User
          include ActiveSupport::Configurable

          config_accessor :hair_colors do
            [:brown, :black, :blonde, :red]
          end
        end

        User.hair_colors # => [:brown, :black, :blonde, :red]

    *Larry Lv*

*   `ActiveSupport::Benchmarkable#silence` has been deprecated due to its lack of
    thread safety. It will be removed without replacement in Rails 4.1.

    *Steve Klabnik*

*   An optional block can be passed to `Hash#deep_merge`. The block will be invoked
    for each duplicated key and used to resolve the conflict.

    *Pranas Kiziela*

*   `ActiveSupport::Deprecation` is now a class. It is possible to create an instance
    of deprecator. Backwards compatibility has been preserved.

    You can choose which instance of the deprecator will be used.

        deprecate :method_name, deprecator: deprecator_instance

    You can use `ActiveSupport::Deprecation` in your gem.

        require 'active_support/deprecation'
        require 'active_support/core_ext/module/deprecation'

        class MyGem
          def self.deprecator
            ActiveSupport::Deprecation.new('2.0', 'MyGem')
          end

          def old_method
          end

          def new_method
          end

          deprecate old_method: :new_method, deprecator: deprecator
        end

        MyGem.new.old_method
        # => DEPRECATION WARNING: old_method is deprecated and will be removed from MyGem 2.0 (use new_method instead). (called from <main> at file.rb:18)

    *Piotr Niełacny & Robert Pankowecki*

*   `ERB::Util.html_escape` encodes single quote as `#39`. Decimal form has better support in old browsers. *Kalys Osmonov*

*   `ActiveSupport::Callbacks`: deprecate monkey patch of object callbacks.
    Using the `filter` method like this:

        before_filter MyFilter.new

        class MyFilter
          def filter(controller)
          end
        end

    Is now deprecated with recommendation to use the corresponding filter type
    (`#before`, `#after` or `#around`):

        before_filter MyFilter.new

        class MyFilter
          def before(controller)
          end
        end

    *Bogdan Gusiev*

*   An optional block can be passed to `HashWithIndifferentAccess#update` and `#merge`.
    The block will be invoked for each duplicated key, and used to resolve the conflict,
    thus replicating the behaviour of the corresponding methods on the `Hash` class.

    *Leo Cassarani*

*   Remove `j` alias for `ERB::Util#json_escape`.
    The `j` alias is already used for `ActionView::Helpers::JavaScriptHelper#escape_javascript`
    and both modules are included in the view context that would confuse the developers.

    *Akira Matsuda*

*   Replace deprecated `memcache-client` gem with `dalli` in `ActiveSupport::Cache::MemCacheStore`.

    *Guillermo Iguaran*

*   Add default values to all `ActiveSupport::NumberHelper` methods, to avoid
    errors with empty locales or missing values.

    *Carlos Antonio da Silva*

*   `ActiveSupport::JSON::Variable` is deprecated. Define your own `#as_json` and
    `#encode_json` methods for custom JSON string literals.

    *Erich Menge*

*   Add `String#indent`. *fxn & Ace Suares*

*   Inflections can now be defined per locale. `singularize` and `pluralize`
    accept locale as an extra argument.

    *David Celis*

*   `Object#try` will now return `nil` instead of raise a `NoMethodError` if the
    receiving object does not implement the method, but you can still get the
    old behavior by using the new `Object#try!`.

    *DHH*

*   `ERB::Util.html_escape` now escapes single quotes. *Santiago Pastorino*

*   `Time#change` now works with time values with offsets other than UTC or the local time zone. *Andrew White*

*   `ActiveSupport::Callbacks`: deprecate usage of filter object with `#before` and `#after` methods as `around` callback. *Bogdan Gusiev*

*   Add `Time#prev_quarter` and `Time#next_quarter` short-hands for `months_ago(3)` and `months_since(3)`. *SungHee Kang*

*   Remove obsolete and unused `require_association` method from dependencies. *fxn*

*   Add `:instance_accessor` option for `config_accessor`.

        class User
          include ActiveSupport::Configurable
          config_accessor :allowed_access, instance_accessor: false
        end

        User.new.allowed_access = true # => NoMethodError
        User.new.allowed_access        # => NoMethodError

    *Francesco Rodriguez*

*   `ActionView::Helpers::NumberHelper` methods have been moved to `ActiveSupport::NumberHelper` and are now available via
    `Numeric#to_s`.  `Numeric#to_s` now accepts the formatting options `:phone`, `:currency`, `:percentage`, `:delimited`,
    `:rounded`, `:human`, and `:human_size`.

    *Andrew Mutz*

*   Add `Hash#transform_keys`, `Hash#transform_keys!`, `Hash#deep_transform_keys`, and `Hash#deep_transform_keys!`. *Mark McSpadden*

*   Changed XML type `datetime` to `dateTime` (with upper case letter `T`). *Angelo Capilleri*

*   Add `:instance_accessor` option for `class_attribute`. *Alexey Vakhov*

*   `constantize` now looks in the ancestor chain. *Marc-Andre Lafortune & Andrew White*

*   Adds `Hash#deep_stringify_keys` and `Hash#deep_stringify_keys!` to convert all keys from a `Hash` instance into strings. *Lucas Húngaro*

*   Adds `Hash#deep_symbolize_keys` and `Hash#deep_symbolize_keys!` to convert all keys from a `Hash` instance into symbols. *Lucas Húngaro*

*   `Object#try` can't call private methods. *Vasiliy Ermolovich*

*   `AS::Callbacks#run_callbacks` remove `key` argument. *Francesco Rodriguez*

*   `deep_dup` works more expectedly now and duplicates also values in `Hash` instances and elements in `Array` instances. *Alexey Gaziev*

*   Inflector no longer applies ice -> ouse to words like "slice", "police", etc. *Wes Morgan*

*   Add `ActiveSupport::Deprecations.behavior = :silence` to completely ignore Rails runtime deprecations. *twinturbo*

*   Make `Module#delegate` stop using `send` - can no longer delegate to private methods. *dasch*

*   `ActiveSupport::Callbacks`: deprecate `:rescuable` option. *Bogdan Gusiev*

*   Adds `Integer#ordinal` to get the ordinal suffix string of an integer. *Tim Gildea*

*   `ActiveSupport::Callbacks`: `:per_key` option is no longer supported. *Bogdan Gusiev*

*   `ActiveSupport::Callbacks#define_callbacks`: add `:skip_after_callbacks_if_terminated` option. *Bogdan Gusiev*

*   Add `html_escape_once` to `ERB::Util`, and delegate the `escape_once` tag helper to it. *Carlos Antonio da Silva*

*   Deprecates the compatibility method `Module#local_constant_names`,
    use `Module#local_constants` instead (which returns symbols). *Xavier Noria*

*   Deletes the compatibility method `Module#method_names`,
    use `Module#methods` from now on (which returns symbols). *Xavier Noria*

*   Deletes the compatibility method `Module#instance_method_names`,
    use `Module#instance_methods` from now on (which returns symbols). *Xavier Noria*

*   `BufferedLogger` is deprecated. Use `ActiveSupport::Logger`, or the logger
    from the Ruby standard library.

    *Aaron Patterson*

*   Unicode database updated to 6.1.0. *Norman Clarke*

*   Adds `encode_big_decimal_as_string` option to force JSON serialization of `BigDecimal` as numeric instead
    of wrapping them in strings for safety.

*   Optimize log subscribers to check log level before doing any processing. *Brian Durand*

Please check [3-2-stable](https://github.com/rails/rails/blob/3-2-stable/activesupport/CHANGELOG.md) for previous changes.
