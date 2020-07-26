*   Fixed issue in `ActiveSupport::Cache::RedisCacheStore` not passing options
    to `read_multi` causing `fetch_multi` to not work properly.

    *Rajesh Sharma*

*   `with_options` copies its options hash again to avoid leaking mutations.

    Fixes #39343.

    *Eugene Kenny*


## Rails 6.0.3.2 (June 17, 2020) ##

*   No changes.


## Rails 6.0.3.1 (May 18, 2020) ##

*   [CVE-2020-8165] Deprecate Marshal.load on raw cache read in RedisCacheStore

*   [CVE-2020-8165] Avoid Marshal.load on raw cache value in MemCacheStore


## Rails 6.0.3 (May 06, 2020) ##

*   `Array#to_sentence` no longer returns a frozen string.

    Before:

        ['one', 'two'].to_sentence.frozen?
        # => true

    After:

        ['one', 'two'].to_sentence.frozen?
        # => false

    *Nicolas Dular*

*   Update `ActiveSupport::Messages::Metadata#fresh?` to work for cookies with expiry set when
    `ActiveSupport.parse_json_times = true`.

    *Christian Gregg*


## Rails 6.0.2.2 (March 19, 2020) ##

*   No changes.


## Rails 6.0.2.1 (December 18, 2019) ##

*   No changes.


## Rails 6.0.2 (December 13, 2019) ##

*   Eager load translations during initialization.

    *Diego Plentz*

*   Use per-thread CPU time clock on `ActiveSupport::Notifications`.

    *George Claghorn*


## Rails 6.0.1 (November 5, 2019) ##

*   `ActiveSupport::SafeBuffer` supports `Enumerator` methods.

    *Shugo Maeda*

*   The Redis cache store fails gracefully when the server returns a "max number
    of clients reached" error.

    *Brandon Medenwald*

*   Fixed that mutating a value returned by a memory cache store would
    unexpectedly change the cached value.

    *Jonathan Hyman*

*   The default inflectors in `zeitwerk` mode support overrides:

    ```ruby
    # config/initializers/zeitwerk.rb
    Rails.autoloaders.each do |autoloader|
      autoloader.inflector.inflect(
        "html_parser" => "HTMLParser",
        "ssl_error"   => "SSLError"
      )
    end
    ```

    That way, you can tweak how individual basenames are inflected without touching Active Support inflection rules, which are global. These inflectors fallback to `String#camelize`, so existing inflection rules are still taken into account for non-overridden basenames.

    Please, check the [autoloading guide for `zeitwerk` mode](https://guides.rubyonrails.org/v6.0/autoloading_and_reloading_constants.html#customizing-inflections) if you prefer not to depend on `String#camelize` at all.

    *Xavier Noria*

*   Improve `Range#===`, `Range#include?`, and `Range#cover?` to work with beginless (startless)
    and endless range targets.

    *Allen Hsu*, *Andrew Hodgkinson*

*   Don't use `Process#clock_gettime(CLOCK_THREAD_CPUTIME_ID)` on Solaris.

    *Iain Beeston*


## Rails 6.0.0 (August 16, 2019) ##

*   Let `require_dependency` in `zeitwerk` mode look the autoload paths up for
    better backwards compatibility.

    *Xavier Noria*

*   Let `require_dependency` in `zeitwerk` mode support arguments that respond
    to `to_path` for better backwards compatibility.

    *Xavier Noria*

*   Make ActiveSupport::Logger Fiber-safe. Fixes #36752.

    Use `Fiber.current.__id__` in `ActiveSupport::Logger#local_level=` in order
    to make log level local to Ruby Fibers in addition to Threads.

    Example:

        logger = ActiveSupport::Logger.new(STDOUT)
        logger.level = 1
        p "Main is debug? #{logger.debug?}"

        Fiber.new {
          logger.local_level = 0
          p "Thread is debug? #{logger.debug?}"
        }.resume

        p "Main is debug? #{logger.debug?}"

    Before:

        Main is debug? false
        Thread is debug? true
        Main is debug? true

    After:

        Main is debug? false
        Thread is debug? true
        Main is debug? false

    *Alexander Varnin*

*   Do not delegate missing `marshal_dump` and `_dump` methods via the
    `delegate_missing_to` extension. This avoids unintentionally adding instance
    variables when calling `Marshal.dump(object)`, should the delegation target of
    `object` be a method which would otherwise add them. Fixes #36522.

    *Aaron Lipman*


## Rails 6.0.0.rc2 (July 22, 2019) ##

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


## Rails 6.0.0.rc1 (April 24, 2019) ##

*   Introduce `ActiveSupport::ActionableError`.

    Actionable errors let's you dispatch actions from Rails' error pages. This
    can help you save time if you have a clear action for the resolution of
    common development errors.

    The de-facto example are pending migrations. Every time pending migrations
    are found, a middleware raises an error. With actionable errors, you can
    run the migrations right from the error page. Other examples include Rails
    plugins that need to run a rake task to setup themselves. They can now
    raise actionable errors to run the setup straight from the error pages.

    Here is how to define an actionable error:

    ```ruby
    class PendingMigrationError < MigrationError #:nodoc:
      include ActiveSupport::ActionableError

      action "Run pending migrations" do
        ActiveRecord::Tasks::DatabaseTasks.migrate
      end
    end
    ```

    To make an error actionable, include the `ActiveSupport::ActionableError`
    module and invoke the `action` class macro to define the action. An action
    needs a name and a procedure to execute. The name is shown as the name of a
    button on the error pages. Once clicked, it will invoke the given
    procedure.

    *Vipul A M*, *Yao Jie*, *Genadi Samokovarov*

*   Preserve `html_safe?` status on `ActiveSupport::SafeBuffer#*`.

    Before:

        ("<br />".html_safe * 2).html_safe? #=> nil

    After:

        ("<br />".html_safe * 2).html_safe? #=> true

    *Ryo Nakamura*

*   Calling test methods with `with_info_handler` method to allow minitest-hooks
    plugin to work.

    *Mauri Mustonen*

*   The Zeitwerk compatibility interface for `ActiveSupport::Dependencies` no
    longer implements `autoloaded_constants` or `autoloaded?` (undocumented,
    anyway). Experience shows introspection does not have many use cases, and
    troubleshooting is done by logging. With this design trade-off we are able
    to use even less memory in all environments.

    *Xavier Noria*

*   Depends on Zeitwerk 2, which stores less metadata if reloading is disabled
    and hence uses less memory when `config.cache_classes` is `true`, a standard
    setup in production.

    *Xavier Noria*

*   In `:zeitwerk` mode, eager load directories in engines and applications only
    if present in their respective `config.eager_load_paths`.

    A common use case for this is adding `lib` to `config.autoload_paths`, but
    not to `config.eager_load_paths`. In that configuration, for example, files
    in the `lib` directory should not be eager loaded.

    *Xavier Noria*

*   Fix bug in Range comparisons when comparing to an excluded-end Range

    Before:

        (1..10).cover?(1...11) # => false

    After:

        (1..10).cover?(1...11) # => true

    With the same change for `Range#include?` and `Range#===`.

    *Owen Stephens*

*   Use weak references in descendants tracker to allow anonymous subclasses to
    be garbage collected.

    *Edgars Beigarts*

*   Update `ActiveSupport::Notifications::Instrumenter#instrument` to make
    passing a block optional. This will let users use
    `ActiveSupport::Notifications` messaging features outside of
    instrumentation.

    *Ali Ibrahim*

*   Fix `Time#advance` to work with dates before 1001-03-07

    Before:

        Time.utc(1001, 3, 6).advance(years: -1) # => 1000-03-05 00:00:00 UTC

    After

        Time.utc(1001, 3, 6).advance(years: -1) # => 1000-03-06 00:00:00 UTC

    Note that this doesn't affect `DateTime#advance` as that doesn't use a proleptic calendar.

    *Andrew White*

*   In Zeitwerk mode, engines are now managed by the `main` autoloader. Engines may reference application constants, if the application is reloaded and we do not reload engines, they won't use the reloaded application code.

    *Xavier Noria*

*   Add support for supplying `locale` to `transliterate` and `parameterize`.

        I18n.backend.store_translations(:de, i18n: { transliterate: { rule: { "ü" => "ue" } } })

        ActiveSupport::Inflector.transliterate("ü", locale: :de) # => "ue"
        "Fünf autos".parameterize(locale: :de) # => "fuenf-autos"
        ActiveSupport::Inflector.parameterize("Fünf autos", locale: :de) # => "fuenf-autos"

    *Kaan Ozkan*, *Sharang Dashputre*

*   Allow `Array#excluding` and `Enumerable#excluding` to deal with a passed array gracefully.

        [ 1, 2, 3, 4, 5 ].excluding([4, 5]) # => [ 1, 2, 3 ]

    *DHH*

*   Renamed `Array#without` and `Enumerable#without` to `Array#excluding` and `Enumerable#excluding`, to create parity with
    `Array#including` and `Enumerable#including`. Retained the old names as aliases.

    *DHH*

*   Added `Array#including` and `Enumerable#including` to conveniently enlarge a collection with more members using a method rather than an operator:

        [ 1, 2, 3 ].including(4, 5) # => [ 1, 2, 3, 4, 5 ]
        post.authors.including(Current.person) # => All the authors plus the current person!

    *DHH*


## Rails 6.0.0.beta3 (March 11, 2019) ##

*   No changes.


## Rails 6.0.0.beta2 (February 25, 2019) ##

*   New autoloading based on [Zeitwerk](https://github.com/fxn/zeitwerk).

    *Xavier Noria*

*   Revise `ActiveSupport::Notifications.unsubscribe` to correctly handle Regex or other multiple-pattern subscribers.

    *Zach Kemp*

*   Add `before_reset` callback to `CurrentAttributes` and define `after_reset` as an alias of `resets` for symmetry.

    *Rosa Gutierrez*

*   Remove the `` Kernel#` `` override that suppresses ENOENT and accidentally returns nil on Unix systems.

    *Akinori Musha*

*   Add `ActiveSupport::HashWithIndifferentAccess#assoc`.

    `assoc` can now be called with either a string or a symbol.

    *Stefan Schüßler*

*   Add `Hash#deep_transform_values`, and `Hash#deep_transform_values!`.

    *Guillermo Iguaran*


## Rails 6.0.0.beta1 (January 18, 2019) ##

*   Remove deprecated `Module#reachable?` method.

    *Rafael Mendonça França*

*   Remove deprecated `#acronym_regex` method from `Inflections`.

    *Rafael Mendonça França*

*   Fix `String#safe_constantize` throwing a `LoadError` for incorrectly cased constant references.

    *Keenan Brock*

*   Preserve key order passed to `ActiveSupport::CacheStore#fetch_multi`.

    `fetch_multi(*names)` now returns its results in the same order as the `*names` requested, rather than returning cache hits followed by cache misses.

    *Gannon McGibbon*

*   If the same block is `included` multiple times for a Concern, an exception is no longer raised.

    *Mark J. Titorenko*, *Vlad Bokov*

*   Fix bug where `#to_options` for `ActiveSupport::HashWithIndifferentAccess`
    would not act as alias for `#symbolize_keys`.

    *Nick Weiland*

*   Improve the logic that detects non-autoloaded constants.

    *Jan Habermann*, *Xavier Noria*

*   Deprecate `ActiveSupport::Multibyte::Unicode#pack_graphemes(array)` and `ActiveSupport::Multibyte::Unicode#unpack_graphemes(string)`
    in favor of `array.flatten.pack("U*")` and `string.scan(/\X/).map(&:codepoints)`, respectively.

    *Francesco Rodríguez*

*   Deprecate `ActiveSupport::Multibyte::Chars.consumes?` in favor of `String#is_utf8?`.

    *Francesco Rodríguez*

*   Fix duration being rounded to a full second.
    ```
      time = DateTime.parse("2018-1-1")
      time += 0.51.seconds
    ```
    Will now correctly add 0.51 second and not 1 full second.

    *Edouard Chin*

*   Deprecate `ActiveSupport::Multibyte::Unicode#normalize` and `ActiveSupport::Multibyte::Chars#normalize`
    in favor of `String#unicode_normalize`

    *Francesco Rodríguez*

*   Deprecate `ActiveSupport::Multibyte::Unicode#downcase/upcase/swapcase` in favor of
    `String#downcase/upcase/swapcase`.

    *Francesco Rodríguez*

*   Add `ActiveSupport::ParameterFilter`.

    *Yoshiyuki Kinjo*

*   Rename `Module#parent`, `Module#parents`, and `Module#parent_name` to
    `module_parent`, `module_parents`, and `module_parent_name`.

    *Gannon McGibbon*

*   Deprecate the use of `LoggerSilence` in favor of `ActiveSupport::LoggerSilence`

    *Edouard Chin*

*   Deprecate using negative limits in `String#first` and `String#last`.

    *Gannon McGibbon*, *Eric Turner*

*   Fix bug where `#without` for `ActiveSupport::HashWithIndifferentAccess` would fail
    with symbol arguments

    *Abraham Chan*

*   Treat `#delete_prefix`, `#delete_suffix` and `#unicode_normalize` results as non-`html_safe`.
    Ensure safety of arguments for `#insert`, `#[]=` and `#replace` calls on `html_safe` Strings.

    *Janosch Müller*

*   Changed `ActiveSupport::TaggedLogging.new` to return a new logger instance instead
    of mutating the one received as parameter.

    *Thierry Joyal*

*   Define `unfreeze_time` as an alias of `travel_back` in `ActiveSupport::Testing::TimeHelpers`.

    The alias is provided for symmetry with `freeze_time`.

    *Ryan Davidson*

*   Add support for tracing constant autoloads. Just throw

        ActiveSupport::Dependencies.logger = Rails.logger
        ActiveSupport::Dependencies.verbose = true

    in an initializer.

    *Xavier Noria*

*   Maintain `html_safe?` on html_safe strings when sliced.

        string = "<div>test</div>".html_safe
        string[-1..1].html_safe? # => true

    *Elom Gomez*, *Yumin Wong*

*   Add `Array#extract!`.

    The method removes and returns the elements for which the block returns a true value.
    If no block is given, an Enumerator is returned instead.

        numbers = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        odd_numbers = numbers.extract! { |number| number.odd? } # => [1, 3, 5, 7, 9]
        numbers # => [0, 2, 4, 6, 8]

    *bogdanvlviv*

*   Support not to cache `nil` for `ActiveSupport::Cache#fetch`.

        cache.fetch('bar', skip_nil: true) { nil }
        cache.exist?('bar') # => false

    *Martin Hong*

*   Add "event object" support to the notification system.
    Before this change, end users were forced to create hand made artisanal
    event objects on their own, like this:

        ActiveSupport::Notifications.subscribe('wait') do |*args|
          @event = ActiveSupport::Notifications::Event.new(*args)
        end

        ActiveSupport::Notifications.instrument('wait') do
          sleep 1
        end

        @event.duration # => 1000.138

    After this change, if the block passed to `subscribe` only takes one
    parameter, the framework will yield an event object to the block.  Now
    end users are no longer required to make their own:

        ActiveSupport::Notifications.subscribe('wait') do |event|
          @event = event
        end

        ActiveSupport::Notifications.instrument('wait') do
          sleep 1
        end

        p @event.allocations # => 7
        p @event.cpu_time    # => 0.256
        p @event.idle_time   # => 1003.2399

    Now you can enjoy event objects without making them yourself.  Neat!

    *Aaron "t.lo" Patterson*

*   Add cpu_time, idle_time, and allocations to Event.

    *Eileen M. Uchitelle*, *Aaron Patterson*

*   RedisCacheStore: support key expiry in increment/decrement.

    Pass `:expires_in` to `#increment` and `#decrement` to set a Redis EXPIRE on the key.

    If the key is already set to expire, RedisCacheStore won't extend its expiry.

        Rails.cache.increment("some_key", 1, expires_in: 2.minutes)

    *Jason Lee*

*   Allow `Range#===` and `Range#cover?` on Range.

    `Range#cover?` can now accept a range argument like `Range#include?` and
    `Range#===`. `Range#===` works correctly on Ruby 2.6. `Range#include?` is moved
    into a new file, with these two methods.

    *Requiring active_support/core_ext/range/include_range is now deprecated.*
    *Use `require "active_support/core_ext/range/compare_range"` instead.*

    *utilum*

*   Add `index_with` to Enumerable.

    Allows creating a hash from an enumerable with the value from a passed block
    or a default argument.

        %i( title body ).index_with { |attr| post.public_send(attr) }
        # => { title: "hey", body: "what's up?" }

        %i( title body ).index_with(nil)
        # => { title: nil, body: nil }

    Closely linked with `index_by`, which creates a hash where the keys are extracted from a block.

    *Kasper Timm Hansen*

*   Fix bug where `ActiveSupport::TimeZone.all` would fail when tzinfo data for
    any timezone defined in `ActiveSupport::TimeZone::MAPPING` is missing.

    *Dominik Sander*

*   Redis cache store: `delete_matched` no longer blocks the Redis server.
    (Switches from evaled Lua to a batched SCAN + DEL loop.)

    *Gleb Mazovetskiy*

*   Fix bug where `ActiveSupport::Cache` will massively inflate the storage
    size when compression is enabled (which is true by default). This patch
    does not attempt to repair existing data: please manually flush the cache
    to clear out the problematic entries.

    *Godfrey Chan*

*   Fix bug where `URI.unescape` would fail with mixed Unicode/escaped character input:

        URI.unescape("\xe3\x83\x90")  # => "バ"
        URI.unescape("%E3%83%90")  # => "バ"
        URI.unescape("\xe3\x83\x90%E3%83%90")  # => Encoding::CompatibilityError

    *Ashe Connor*, *Aaron Patterson*

*   Add `before?` and `after?` methods to `Date`, `DateTime`,
    `Time`, and `TimeWithZone`.

    *Nick Holden*

*   `ActiveSupport::Inflector#ordinal` and `ActiveSupport::Inflector#ordinalize` now support
    translations through I18n.

        # locale/fr.rb

        {
          fr: {
            number: {
              nth: {
                ordinals: lambda do |_key, number:, **_options|
                  if number.to_i.abs == 1
                    'er'
                  else
                    'e'
                  end
                end,

                ordinalized: lambda do |_key, number:, **_options|
                  "#{number}#{ActiveSupport::Inflector.ordinal(number)}"
                end
              }
            }
          }
        }


    *Christian Blais*

*   Add `:private` option to ActiveSupport's `Module#delegate`
    in order to delegate methods as private:

        class User < ActiveRecord::Base
          has_one :profile
          delegate :date_of_birth, to: :profile, private: true

          def age
            Date.today.year - date_of_birth.year
          end
        end

        # User.new.age  # => 29
        # User.new.date_of_birth
        # => NoMethodError: private method `date_of_birth' called for #<User:0x00000008221340>

    *Tomas Valent*

*   `String#truncate_bytes` to truncate a string to a maximum bytesize without
    breaking multibyte characters or grapheme clusters like 👩‍👩‍👦‍👦.

    *Jeremy Daer*

*   `String#strip_heredoc` preserves frozenness.

        "foo".freeze.strip_heredoc.frozen?  # => true

    Fixes that frozen string literals would inadvertently become unfrozen:

        # frozen_string_literal: true

        foo = <<-MSG.strip_heredoc
          la la la
        MSG

        foo.frozen?  # => false !??

    *Jeremy Daer*

*   Rails 6 requires Ruby 2.5.0 or newer.

    *Jeremy Daer*, *Kasper Timm Hansen*

*   Adds parallel testing to Rails.

    Parallelize your test suite with forked processes or threads.

    *Eileen M. Uchitelle*, *Aaron Patterson*


Please check [5-2-stable](https://github.com/rails/rails/blob/5-2-stable/activesupport/CHANGELOG.md) for previous changes.
