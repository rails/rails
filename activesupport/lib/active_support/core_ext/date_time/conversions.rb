module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module DateTime #:nodoc:
      # Converting datetimes to formatted strings, dates, and times.
      module Conversions
        def self.included(base) #:nodoc:
          base.class_eval do
            alias_method :to_datetime_default_s, :to_s
            alias_method :to_s, :to_formatted_s
            alias_method :default_inspect, :inspect
            alias_method :inspect, :readable_inspect

            # Ruby 1.9 has DateTime#to_time which internally relies on Time. We define our own #to_time which allows
            # DateTimes outside the range of what can be created with Time.
            remove_method :to_time if base.instance_methods.include?(:to_time)
          end
        end

        # Convert to a formatted string. See Time::DATE_FORMATS for predefined formats.
        # 
        # This method is aliased to <tt>to_s</tt>.
        # 
        # === Examples:
        #   datetime = DateTime.civil(2007, 12, 4, 0, 0, 0, 0)   # => Tue, 04 Dec 2007 00:00:00 +0000
        # 
        #   datetime.to_formatted_s(:db)            # => "2007-12-04 00:00:00"
        #   datetime.to_s(:db)                      # => "2007-12-04 00:00:00"
        #   datetime.to_s(:number)                  # => "20071204000000"
        #   datetime.to_formatted_s(:short)         # => "04 Dec 00:00"
        #   datetime.to_formatted_s(:long)          # => "December 04, 2007 00:00"
        #   datetime.to_formatted_s(:long_ordinal)  # => "December 4th, 2007 00:00"
        #   datetime.to_formatted_s(:rfc822)        # => "Tue, 04 Dec 2007 00:00:00 +0000"
        #
        # == Adding your own datetime formats to to_formatted_s
        # DateTime formats are shared with Time. You can add your own to the
        # Time::DATE_FORMATS hash. Use the format name as the hash key and
        # either a strftime string or Proc instance that takes a time or
        # datetime argument as the value.
        #
        #   # config/initializers/time_formats.rb
        #   Time::DATE_FORMATS[:month_and_year] = "%B %Y"
        #   Time::DATE_FORMATS[:short_ordinal] = lambda { |time| time.strftime("%B #{time.day.ordinalize}") }
        def to_formatted_s(format = :default)
          if formatter = ::Time::DATE_FORMATS[format]
            if formatter.respond_to?(:call)
              formatter.call(self).to_s
            else
              strftime(formatter)
            end
          else
            to_datetime_default_s
          end
        end

        # Overrides the default inspect method with a human readable one, e.g., "Mon, 21 Feb 2005 14:30:00 +0000"
        def readable_inspect
          to_s(:rfc822)
        end

        # Converts self to a Ruby Date object; time portion is discarded
        def to_date
          ::Date.new(year, month, day)
        end

        # Attempts to convert self to a Ruby Time object; returns self if out of range of Ruby Time class
        # If self has an offset other than 0, self will just be returned unaltered, since there's no clean way to map it to a Time
        def to_time
          self.offset == 0 ? ::Time.utc_time(year, month, day, hour, min, sec) : self
        end

        # To be able to keep Times, Dates and DateTimes interchangeable on conversions
        def to_datetime
          self
        end

        # Converts datetime to an appropriate format for use in XML
        def xmlschema
          strftime("%Y-%m-%dT%H:%M:%S%Z")
        end if RUBY_VERSION < '1.9'
      end
    end
  end
end
