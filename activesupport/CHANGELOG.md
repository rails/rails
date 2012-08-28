## Rails 4.0.0 (unreleased) ##

*   Remove `j` alias for `ERB::Util#json_escape`.
    The `j` alias is already used for `ActionView::Helpers::JavaScriptHelper#escape_javascript`
    and both modules are included in the view context that would confuse the developers.

    *Akira Matsuda*

*   Replace deprecated `memcache-client` gem with `dalli` in ActiveSupport::Cache::MemCacheStore

    *Guillermo Iguaran*

*   Add default values to all `ActiveSupport::NumberHelper` methods, to avoid
    errors with empty locales or missing values.

    *Carlos Antonio da Silva*

*   ActiveSupport::JSON::Variable is deprecated. Define your own #as_json and
    #encode_json methods for custom JSON string literals.

    *Erich Menge*

*   Add String#indent. *fxn & Ace Suares*

*   Inflections can now be defined per locale. `singularize` and `pluralize`
    accept locale as an extra argument.

    *David Celis*

*   `Object#try` will now return nil instead of raise a NoMethodError if the
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

*   ActionView::Helpers::NumberHelper methods have been moved to ActiveSupport::NumberHelper and are now available via
    Numeric#to_s.  Numeric#to_s now accepts the formatting  options :phone, :currency, :percentage, :delimited,
    :rounded, :human, and :human_size. *Andrew Mutz*

*   Add `Hash#transform_keys`, `Hash#transform_keys!`, `Hash#deep_transform_keys`, and `Hash#deep_transform_keys!`. *Mark McSpadden*

*   Changed xml type `datetime` to `dateTime` (with upper case letter `T`). *Angelo Capilleri*

*   Add `:instance_accessor` option for `class_attribute`. *Alexey Vakhov*

*   `constantize` now looks in the ancestor chain. *Marc-Andre Lafortune & Andrew White*

*   Adds `Hash#deep_stringify_keys` and `Hash#deep_stringify_keys!` to convert all keys from a +Hash+ instance into strings *Lucas Húngaro*

*   Adds `Hash#deep_symbolize_keys` and `Hash#deep_symbolize_keys!` to convert all keys from a +Hash+ instance into symbols *Lucas Húngaro*

*   `Object#try` can't call private methods. *Vasiliy Ermolovich*

*   `AS::Callbacks#run_callbacks` remove `key` argument. *Francesco Rodriguez*

*   `deep_dup` works more expectedly now and duplicates also values in +Hash+ instances and elements in +Array+ instances. *Alexey Gaziev*

*   Inflector no longer applies ice -> ouse to words like slice, police, ets *Wes Morgan*

*   Add `ActiveSupport::Deprecations.behavior = :silence` to completely ignore Rails runtime deprecations *twinturbo*

*   Make Module#delegate stop using `send` - can no longer delegate to private methods. *dasch*

*   AS::Callbacks: deprecate `:rescuable` option. *Bogdan Gusiev*

*   Adds Integer#ordinal to get the ordinal suffix string of an integer. *Tim Gildea*

*   AS::Callbacks: `:per_key` option is no longer supported

*   `AS::Callbacks#define_callbacks`: add `:skip_after_callbacks_if_terminated` option.

*   Add html_escape_once to ERB::Util, and delegate escape_once tag helper to it. *Carlos Antonio da Silva*

*   Remove ActiveSupport::TestCase#pending method, use `skip` instead. *Carlos Antonio da Silva*

*   Deprecates the compatibility method Module#local_constant_names,
    use Module#local_constants instead (which returns symbols). *fxn*

*   Deletes the compatibility method Module#method_names,
    use Module#methods from now on (which returns symbols). *fxn*

*   Deletes the compatibility method Module#instance_method_names,
    use Module#instance_methods from now on (which returns symbols). *fxn*

*   BufferedLogger is deprecated.  Use ActiveSupport::Logger, or the logger
    from Ruby stdlib.

*   Unicode database updated to 6.1.0.

*   Adds `encode_big_decimal_as_string` option to force JSON serialization of BigDecimals as numeric instead
    of wrapping them in strings for safety.

*   Remove deprecated ActiveSupport::JSON::Variable. *Erich Menge*

Please check [3-2-stable](https://github.com/rails/rails/blob/3-2-stable/activesupport/CHANGELOG.md) for previous changes.
