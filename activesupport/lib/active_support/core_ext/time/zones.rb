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
          # Rails TimeZone object (e.g., "Central Time (US & Canada)"), or a TZInfo::Timezone object.
          #
          # Any Time or DateTime object can use this default time zone, via <tt>in_time_zone</tt>.
          #
          #   Time.zone = 'Hawaii'          # => 'Hawaii'
          #   Time.utc(2000).in_time_zone   # => Fri, 31 Dec 1999 14:00:00 HST -10:00
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
              return time_zone if time_zone.nil? || time_zone.is_a?(TimeZone)
              # lookup timezone based on identifier (unless we've been passed a TZInfo::Timezone)
              unless time_zone.respond_to?(:period_for_local)
                time_zone = TimeZone[time_zone] || TZInfo::Timezone.get(time_zone) rescue nil
              end
              # Return if a TimeZone instance, or wrap in a TimeZone instance if a TZInfo::Timezone
              if time_zone
                time_zone.is_a?(TimeZone) ? time_zone : TimeZone.create(time_zone.name, nil, time_zone)
              end
            end
        end
        
        # Returns the simultaneous time in Time.zone.
        #
        #   Time.zone = 'Hawaii'         # => 'Hawaii'
        #   Time.utc(2000).in_time_zone  # => Fri, 31 Dec 1999 14:00:00 HST -10:00
        #
        # This method is similar to Time#localtime, except that it uses Time.zone as the local zone
        # instead of the operating system's time zone.
        #
        # You can also pass in a TimeZone instance or string that identifies a TimeZone as an argument, 
        # and the conversion will be based on that zone instead of Time.zone.
        #
        #   Time.utc(2000).in_time_zone('Alaska')  # => Fri, 31 Dec 1999 15:00:00 AKST -09:00
        def in_time_zone(zone = ::Time.zone)
          ActiveSupport::TimeWithZone.new(utc? ? self : getutc, ::Time.send!(:get_zone, zone))
        end
      end
    end
  end
end