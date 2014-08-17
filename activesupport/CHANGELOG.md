*   Fix rounding errors with #travel_to by resetting the usec on any passed time to zero, so we only travel
    with per-second precision, not anything deeper than that.
    
    *DHH*

*   Fix ActiveSupport::TestCase not to order users' test cases by default.
    If this change breaks your tests because your tests are order dependent, you need to explicitly call
    ActiveSupport::TestCase.my_tests_are_order_dependent! at the top of your tests.

    *Akira Matsuda*

*   Fix DateTime comparison with DateTime::Infinity object.

    *Rafael Mendonça França*

*   Added Object#itself which returns the object itself. Useful when dealing with a chaining scenario, like Active Record scopes:

        Event.public_send(state.presence_in([ :trashed, :drafted ]) || :itself).order(:created_at)

    *DHH*

*   `Object#with_options` executes block in merging option context when
    explicit receiver in not passed.

    *Pavel Pravosud*

*   Fixed a compatibility issue with the `Oj` gem when cherry-picking the file
    `active_support/core_ext/object/json` without requiring `active_support/json`.

    Fixes #16131.

    *Godfrey Chan*

*   Make `Hash#with_indifferent_access` copy the default proc too.

    *arthurnn*, *Xanders*

*   Add `String#truncate_words` to truncate a string by a number of words.

    *Mohamed Osama*

*   Deprecate `capture` and `quietly`.

    These methods are not thread safe and may cause issues when used in threaded environments.
    To avoid problems we are deprecating them.

    *Tom Meier*

*   `DateTime#to_f` now preserves the fractional seconds instead of always
    rounding to `.0`.

    Fixes #15994.

    *John Paul Ashenfelter*

*   Add `Hash#transform_values` to simplify a common pattern where the values of a
    hash must change, but the keys are left the same.

    *Sean Griffin*

*   Always instrument `ActiveSupport::Cache`.

    Since `ActiveSupport::Notifications` only instrument items when there
    are subscriber we don't need to disable instrumentation.

    *Peter Wagenet*

*   Make the `apply_inflections` method case-insensitive when checking
    whether a word is uncountable or not.

    *Robin Dupret*

*   Make Dependencies pass a name to NameError error.

    *arthurnn*

*   Fixed `ActiveSupport::Cache::FileStore` exploding with long paths.

    *Adam Panzer / Michael Grosser*

*   Fixed `ActiveSupport::TimeWithZone#-` so precision is not unnecessarily lost
    when working with objects with a nanosecond component.

    `ActiveSupport::TimeWithZone#-` should return the same result as if we were
    using `Time#-`:

        Time.now.end_of_day - Time.now.beginning_of_day #=> 86399.999999999

    Before:

        Time.zone.now.end_of_day.nsec #=> 999999999
        Time.zone.now.end_of_day - Time.zone.now.beginning_of_day #=> 86400.0

    After:

        Time.zone.now.end_of_day - Time.zone.now.beginning_of_day
        #=> 86399.999999999

    *Gordon Chan*

*   Fixed precision error in NumberHelper when using Rationals.

    Before:

        ActiveSupport::NumberHelper.number_to_rounded Rational(1000, 3), precision: 2
        #=> "330.00"

    After:

        ActiveSupport::NumberHelper.number_to_rounded Rational(1000, 3), precision: 2
        #=> "333.33"

    See #15379.

    *Juanjo Bazán*

*   Removed deprecated `Numeric#ago` and friends

    Replacements:

        5.ago   => 5.seconds.ago
        5.until => 5.seconds.until
        5.since => 5.seconds.since
        5.from_now => 5.seconds.from_now

    See #12389 for the history and rationale behind this.

    *Godfrey Chan*

*   DateTime `advance` now supports partial days.

    Before:

        DateTime.now.advance(days: 1, hours: 12)

    After:

        DateTime.now.advance(days: 1.5)

    Fixes #12005.

    *Shay Davidson*

*   `Hash#deep_transform_keys` and `Hash#deep_transform_keys!` now transform hashes
    in nested arrays.  This change also applies to `Hash#deep_stringify_keys`,
    `Hash#deep_stringify_keys!`, `Hash#deep_symbolize_keys` and
    `Hash#deep_symbolize_keys!`.

    *OZAWA Sakuro*

*   Fixed confusing `DelegationError` in `Module#delegate`.

    See #15186.

    *Vladimir Yarotsky*

*   Fixed `ActiveSupport::Subscriber` so that no duplicate subscriber is created
    when a subscriber method is redefined.

    *Dennis Schön*

*   Remove deprecated string based terminators for `ActiveSupport::Callbacks`.

    *Eileen M. Uchitelle*

*   Fixed an issue when using
    `ActiveSupport::NumberHelper::NumberToDelimitedConverter` to
    convert a value that is an `ActiveSupport::SafeBuffer` introduced
    in 2da9d67.

    See #15064.

    *Mark J. Titorenko*

*   `TimeZone#parse` defaults the day of the month to '1' if any other date
    components are specified. This is more consistent with the behavior of
    `Time#parse`.

    *Ulysse Carion*

*   `humanize` strips leading underscores, if any.

    Before:

        '_id'.humanize # => ""

    After:

        '_id'.humanize # => "Id"

    *Xavier Noria*

*   Fixed backward compatibility isues introduced in 326e652.

    Empty Hash or Array should not present in serialization result.

        {a: []}.to_query # => ""
        {a: {}}.to_query # => ""

    For more info see #14948.

    *Bogdan Gusiev*

*   Add `Digest::UUID::uuid_v3` and `Digest::UUID::uuid_v5` to support stable
    UUID fixtures on PostgreSQL.

    *Roderick van Domburg*

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
    given. In particular, `.new`, `#update`, `#merge`, `#replace` all accept
    objects which respond to `#to_hash`, even if those objects are not Hashes
    directly.

    *Peter Jaros*

*   Deprecate `Class#superclass_delegating_accessor`, use `Class#class_attribute` instead.

    *Akshay Vishnoi*

*   Ensure classes which `include Enumerable` get `#to_json` in addition to
    `#as_json`.

    *Sammy Larbi*

*   Change the signature of `fetch_multi` to return a hash rather than an
    array. This makes it consistent with the output of `read_multi`.

    *Parker Selbert*

*   Introduce `Concern#class_methods` as a sleek alternative to clunky
    `module ClassMethods`. Add `Kernel#concern` to define at the toplevel
    without chunky `module Foo; extend ActiveSupport::Concern` boilerplate.

        # app/models/concerns/authentication.rb
        concern :Authentication do
          included do
            after_create :generate_private_key
          end

          class_methods do
            def authenticate(credentials)
              # ...
            end
          end

          def generate_private_key
            # ...
          end
        end

        # app/models/user.rb
        class User < ActiveRecord::Base
          include Authentication
        end

    *Jeremy Kemper*

Please check [4-1-stable](https://github.com/rails/rails/blob/4-1-stable/activesupport/CHANGELOG.md) for previous changes.
