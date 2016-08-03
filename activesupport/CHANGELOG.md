*   Since weeks are no longer converted to days, add `:weeks` to the list of
    parts that `ActiveSupport::TimeWithZone` will recognize as possibly being
    of variable duration to take account of DST transitions.

    Fixes #26039.

    *Andrew White*

*   Defines `Regexp.match?` for Ruby versions prior to 2.4. The predicate
    has the same interface, but it does not have the performance boost. Its
    purpose is to be able to write 2.4 compatible code.

    *Xavier Noria*

*   Allow MessageEncryptor to take advantage of authenticated encryption modes.

    AEAD modes like `aes-256-gcm` provide both confidentiality and data
    authenticity, eliminating the need to use MessageVerifier to check if the
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

*   Introduce Module#delegate_missing_to.

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
