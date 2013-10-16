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

*   Add String#remove(pattern) as a short-hand for the common pattern of String#gsub(pattern, '')

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
    1.9.3 and 2.0. GH#11512

    *Simeon Simeonov*

*   Only raise `Module::DelegationError` if it's the source of the exception.

    Fixes #10559

    *Andrew White*

*   Make `Time.at_with_coercion` retain the second fraction and return local time.

    Fixes #11350

    *Neer Friedman*, *Andrew White*

*   Make `HashWithIndifferentAccess#select` always return the hash, even when
    `Hash#select!` returns `nil`, to allow further chaining.

    *Marc Schütz*

*   Remove deprecated `String#encoding_aware?` core extensions (`core_ext/string/encoding`).

    *Arun Agrawal*

*   Remove deprecated `Module#local_constant_names` in favor of `Module#local_constants`.

    *Arun Agrawal*

*   Remove deprecated `DateTime.local_offset` in favor of `DateTime.civil_from_fromat`.

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

*   Remove deprecated `BufferedLogger`.

    *Yves Senn*

*   Remove deprecated `assert_present` and `assert_blank` methods.

    *Yves Senn*

*   Fix return value from `BacktraceCleaner#noise` when the cleaner is configured
    with multiple silencers.

    Fixes #11030

    *Mark J. Titorenko*

*   `HashWithIndifferentAccess#select` now returns a `HashWithIndifferentAccess`
    instance instead of a `Hash` instance.

    Fixes #10723

    *Albert Llop*

*   Add `DateTime#usec` and `DateTime#nsec` so that `ActiveSupport::TimeWithZone` keeps
    sub-second resolution when wrapping a `DateTime` value.

    Fixes #10855

    *Andrew White*

*   Fix `ActiveSupport::Dependencies::Loadable#load_dependency` calling
    `#blame_file!` on Exceptions that do not have the Blamable mixin

    *Andrew Kreiling*

*   Override `Time.at` to support the passing of Time-like values when called with a single argument.

    *Andrew White*

*   Prevent side effects to hashes inside arrays when
    `Hash#with_indifferent_access` is called.

    Fixes #10526

    *Yves Senn*

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
