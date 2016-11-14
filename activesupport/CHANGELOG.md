*   Remove deprecated class `ActiveSupport::Concurrency::Latch`

    *Andrew White*

*   Remove deprecated separator argument from `parameterize`

    *Andrew White*

*   Remove deprecated method `Numeric#to_formatted_s`

    *Andrew White*

*   Remove deprecated method `alias_method_chain`

    *Andrew White*

*   Remove deprecated constant `MissingSourceFile`

    *Andrew White*

*   Remove deprecated methods `Module.qualified_const_defined?`,
    `Module.qualified_const_get` and `Module.qualified_const_set`

    *Andrew White*

*   Remove deprecated `:prefix` option from `number_to_human_size`

    *Andrew White*

*   Remove deprecated method `ActiveSupport::HashWithIndifferentAccess.new_from_hash_copying_default`

    *Andrew White*

*   Remove deprecated method `Module.local_constants`

    *Andrew White*

*   Remove deprecated file `active_support/core_ext/time/marshal.rb`

    *Andrew White*

*   Remove deprecated file `active_support/core_ext/struct.rb`

    *Andrew White*

*   Remove deprecated file `active_support/core_ext/module/method_transplanting.rb`

    *Andrew White*

*   Remove deprecated method `Module.local_constants`

    *Andrew White*

*   Remove deprecated file `active_support/core_ext/kernel/debugger.rb`

    *Andrew White*

*   Remove deprecated method `ActiveSupport::Cache::Store#namespaced_key`

    *Andrew White*

*   Remove deprecated method `ActiveSupport::Cache::Strategy::LocalCache::LocalStore#set_cache_value`

    *Andrew White*

*   Remove deprecated method `ActiveSupport::Cache::MemCacheStore#escape_key`

    *Andrew White*

*   Remove deprecated method `ActiveSupport::Cache::FileStore#key_file_path`

    *Andrew White*

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

*   Add `:fallback_string` option to `Array#to_sentence`. If an empty array
    calls the function and a fallback string option is set then it returns the
    fallback string other than an empty string.

    *Mohamed Osama*

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
