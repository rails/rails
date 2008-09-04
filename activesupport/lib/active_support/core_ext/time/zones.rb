module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Time #:nodoc:
      module Zones
        def self.included(base) #:nodoc:
          base.extend(ClassMethods) if base == ::Time # i.e., don't include class methods in DateTime
        end
        
        module ClassMethods
          attr_accessor :zone_default
          
          # Returns the TimeZone for the current request, if this has been set (via Time.zone=). 
          # If <tt>Time.zone</tt> has not been set for the current request, returns the TimeZone specified in <tt>config.time_zone</tt>.
          def zone
            Thread.current[:time_zone] || zone_default
          end

          # Sets <tt>Time.zone</tt> to a TimeZone object for the current request/thread. 
          #
          # This method accepts any of the following:
          #
          # * A Rails TimeZone object.
          # * An identifier for a Rails TimeZone object (e.g., "Eastern Time (US & Canada)", <tt>-5.hours</tt>).
          # * A TZInfo::Timezone object.
          # * An identifier for a TZInfo::Timezone object (e.g., "America/New_York").
          #
          # Here's an example of how you might set <tt>Time.zone</tt> on a per request basis -- <tt>current_user.time_zone</tt>
          # just needs to return a string identifying the user's preferred TimeZone:
          #
          #   class ApplicationController < ActionController::Base
          #     before_filter :set_time_zone
          #
          #     def set_time_zone
          #       Time.zone = current_user.time_zone
          #     end
          #   end
          def zone=(time_zone)
            Thread.current[:time_zone] = get_zone(time_zone)
          end
          
          # Allows override of <tt>Time.zone</tt> locally inside supplied block; resets <tt>Time.zone</tt> to existing value when done.
          def use_zone(time_zone)
            old_zone, ::Time.zone = ::Time.zone, get_zone(time_zone)
            yield
          ensure
            ::Time.zone = old_zone
          end
          
          # Returns <tt>Time.zone.now</tt> when <tt>config.time_zone</tt> is set, otherwise just returns <tt>Time.now</tt>.
          def current
            ::Time.zone_default ? ::Time.zone.now : ::Time.now
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
        
        # Returns the simultaneous time in <tt>Time.zone</tt>.
        #
        #   Time.zone = 'Hawaii'         # => 'Hawaii'
        #   Time.utc(2000).in_time_zone  # => Fri, 31 Dec 1999 14:00:00 HST -10:00
        #
        # This method is similar to Time#localtime, except that it uses <tt>Time.zone</tt> as the local zone
        # instead of the operating system's time zone.
        #
        # You can also pass in a TimeZone instance or string that identifies a TimeZone as an argument, 
        # and the conversion will be based on that zone instead of <tt>Time.zone</tt>.
        #
        #   Time.utc(2000).in_time_zone('Alaska')  # => Fri, 31 Dec 1999 15:00:00 AKST -09:00
        def in_time_zone(zone = ::Time.zone)
          ActiveSupport::TimeWithZone.new(utc? ? self : getutc, ::Time.__send__(:get_zone, zone))
        end
      end
    end
  end
end