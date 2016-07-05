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
