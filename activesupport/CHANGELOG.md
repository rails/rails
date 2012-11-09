## Rails 4.0.0 (unreleased) ##

*   Deprecate Hash#diff in favor of MiniTest's #diff. *Steve Klabnik*

*   Kernel#capture can catch output from subprocesses *Dmitry Vorotilin*

*   `to_xml` conversions now use builder's `tag!` method instead of explicit invocation of `method_missing`.

    *Nikita Afanasenko*

*   Fixed timezone mapping of the Solomon Islands. *Steve Klabnik*

*   Make callstack attribute optional in
    ActiveSupport::Deprecation::Reporting methods `warn` and `deprecation_warning`

    *Alexey Gaziev*

*   Implement HashWithIndifferentAccess#replace so key? works correctly. *David Graham*

*   Handle the possible Permission Denied errors atomic.rb might trigger due to its chown and chmod calls. *Daniele Sluijters*

*   Hash#extract! returns only those keys that present in the receiver.

        {:a => 1, :b => 2}.extract!(:a, :x) # => {:a => 1}

    *Mikhail Dieterle*

*   Hash#extract! returns the same subclass, that the receiver is. I.e.
    HashWithIndifferentAccess#extract! returns HashWithIndifferentAccess instance.

    *Mikhail Dieterle*

*   Optimize ActiveSupport::Cache::Entry to reduce memory and processing overhead. *Brian Durand*

*   Tests tag the Rails log with the current test class and test case:

        [SessionsControllerTest] [test_0002_sign in] Processing by SessionsController#create as HTML
        [SessionsControllerTest] [test_0002_sign in] ...

    *Jeremy Kemper*

*   Add logger.push_tags and .pop_tags to complement logger.tagged:

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

*   ActiveSupport::Benchmarkable#silence has been deprecated due to its lack of
    thread safety. It will be removed without replacement in Rails 4.1.

    *Steve Klabnik*

*   An optional block can be passed to `Hash#deep_merge`. The block will be invoked
    for each duplicated key and used to resolve the conflict.

    *Pranas Kiziela*

*   ActiveSupport::Deprecation is now a class. It is possible to create an instance
    of deprecator. Backwards compatibility has been preserved.

    You can choose which instance of the deprecator will be used.

        deprecate :method_name, :deprecator => deprecator_instance

    You can use ActiveSupport::Deprecation in your gem.

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

          deprecate :old_method => :new_method, :deprecator => deprecator
        end

        MyGem.new.old_method
        # => DEPRECATION WARNING: old_method is deprecated and will be removed from MyGem 2.0 (use new_method instead). (called from <main> at file.rb:18)

    *Piotr Niełacny & Robert Pankowecki*

*   `ERB::Util.html_escape` encodes single quote as `#39`. Decimal form has better support in old browsers. *Kalys Osmonov*

*   `ActiveSupport::Callbacks`: deprecate monkey patch of object callbacks.
    Using the #filter method like this:

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

*   Replace deprecated `memcache-client` gem with `dalli` in ActiveSupport::Cache::MemCacheStore

    *Guillermo Iguaran*

*   Add default values to all `ActiveSupport::NumberHelper` methods, to avoid
    errors with empty locales or missing values.

    *Carlos Antonio da Silva*

*   `ActiveSupport::JSON::Variable` is deprecated. Define your own `#as_json` and
    `#encode_json` methods for custom JSON string literals.

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

*   Optimize log subscribers to check log level before doing any processing. *Brian Durand*

Please check [3-2-stable](https://github.com/rails/rails/blob/3-2-stable/activesupport/CHANGELOG.md) for previous changes.
