module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Time #:nodoc:
      # Methods for creating TimeWithZone objects from Time instances
      module Zones
        
        def self.included(base) #:nodoc:
          base.extend(ClassMethods) if base == ::Time # i.e., don't include class methods in DateTime
        end
        
        module ClassMethods
          attr_accessor :zone_default
          
          def zone
            Thread.current[:time_zone] || zone_default
          end

          # Sets a global default time zone, separate from the system time zone in ENV['TZ']. 
          # Accepts either a Rails TimeZone object, a string that identifies a 
          # Rails TimeZone object (e.g., "Central Time (US & Canada)"), or a TZInfo::Timezone object
          #
          # Any Time or DateTime object can use this default time zone, via #in_current_time_zone.
          # Example:
          #
          #   Time.zone = 'Hawaii'                  # => 'Hawaii'
          #   Time.utc(2000).in_current_time_zone   # => Fri, 31 Dec 1999 14:00:00 HST -10:00
          def zone=(time_zone)
            Thread.current[:time_zone] = get_zone(time_zone)
          end
          
          # Allows override of Time.zone locally inside supplied block; resets Time.zone to existing value when done
          def use_zone(time_zone)
            old_zone, ::Time.zone = ::Time.zone, get_zone(time_zone)
            yield
          ensure
            ::Time.zone = old_zone
          end
          
          private
            def get_zone(time_zone)
              return time_zone if time_zone.nil? || time_zone.respond_to?(:period_for_local)
              TimeZone[time_zone]
            end
        end
        
        # Returns the simultaneous time in the supplied zone. Examples:
        #
        #   t = Time.utc(2000)        # => Sat Jan 01 00:00:00 UTC 2000
        #   t.in_time_zone('Alaska')  # => Fri, 31 Dec 1999 15:00:00 AKST -09:00
        #   t.in_time_zone('Hawaii')  # => Fri, 31 Dec 1999 14:00:00 HST -10:00
        def in_time_zone(zone)
          ActiveSupport::TimeWithZone.new(utc? ? self : getutc, get_zone(zone))
        end

        # Returns the simultaneous time in Time.zone
        def in_current_time_zone
          ::Time.zone ? in_time_zone(::Time.zone) : self
        end

        # Replaces the existing zone; leaves time values intact. Examples:
        #
        #   t = Time.utc(2000)            # => Sat Jan 01 00:00:00 UTC 2000
        #   t.change_time_zone('Alaska')  # => Sat, 01 Jan 2000 00:00:00 AKST -09:00
        #   t.change_time_zone('Hawaii')  # => Sat, 01 Jan 2000 00:00:00 HST -10:00
        #
        # Note the difference between this method and #in_time_zone: #in_time_zone does a calculation to determine
        # the simultaneous time in the supplied zone, whereas #change_time_zone does no calculation; it just
        # "dials in" a new time zone for +self+
        def change_time_zone(zone)
          ActiveSupport::TimeWithZone.new(nil, get_zone(zone), self)
        end
        
        private
          def get_zone(time_zone)
            ::Time.send!(:get_zone, time_zone)
          end
      end
    end
  end
end