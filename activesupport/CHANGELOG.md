*   Introduce next_*day and prev_*day helpers for Date, DateTime and Time  

    Rails provides the Date#next_week method, but at times this is not the required date.
    For example, if today is a Monday and there is a need for the next Tuesday, one way is to loop through
    the next seven days to get the first match for Tuesday, or to blindly use the next_week(:tuesday)
    method, which would usually not be the required value.

    This implementation adds the Date#(next_sunday..next_saturday) and Date#(prev_sunday..prev_saturday), which would be super helpful for
    these purposes. It finds the next_*day relative to the current date, being used.
    Usage example:

    With this implementation, to get the next 4 Thursdays for a list, it can easily be achieved with the snippet below:

        4.times{ |i|
           Date.today.next_thursday + i.week
        }

        Date.today.next_tuesday # if the next day is a Tueday, it should return tomorrow, else next_week's
        Date.today.prev_tuesday # if the previous day is a Tueday, it should return yesterday, else prev_week's

    This uses the Calculations API to achieve this efficiently.

    *Oreoluwa Akinniranye*

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
