
module DateAndTime
  module Conversions

    def self.included(klass)
      klass.class_eval do
        alias_method :to_default_s, :to_s if instance_methods(false).include?(:to_s)
        alias_method :to_s, :to_formatted_s
      end
    end

    # Convert to a formatted string.
    # See Time::DATE_FORMATS and Date::DATE_FORMATS for predefined formats.
    #
    # This method is aliased to +to_s+.
    #
    #   date = Date.new(2007, 11, 10)           # => Sat, 10 Nov 2007
    #   time = Time.now                         # => Thu Jan 18 06:10:17 CST 2007
    #   datetime = DateTime.civil(2007, 11, 10, 0, 0, 0, 0)
    #                                           # => Sat, 10 Nov 2007 00:00:00 +0000
    #
    #   date.to_formatted_s(:db)                # => "2007-11-10"
    #   date.to_s(:db)                          # => "2007-11-10"
    #
    #   time.to_formatted_s(:time)              # => "06:10"
    #   time.to_s(:time)                        # => "06:10"
    #
    #   datetime.to_formatted_s(:db)            # => "2007-11-10 00:00:00"
    #   datetime.to_s(:db)                      # => "2007-11-10 00:00:00"
    #
    #   date.to_formatted_s(:short)             # => "10 Nov"
    #   time.to_formatted_s(:short)             # => "18 Jan 06:10"
    #   datetime.to_formatted_s(:short)         # => "10 Nov 00:00"
    #
    #   date.to_formatted_s(:long)              # => "November 10, 2007"
    #   time.to_formatted_s(:long)              # => "January 18, 2007 06:10"
    #   datetime.to_formatted_s(:long)          # => "November 10, 2007 00:00"
    #
    #   date.to_formatted_s(:long_ordinal)      # => "November 10th, 2007"
    #   time.to_formatted_s(:long_ordinal)      # => "January 18th, 2007 06:10"
    #   datetime.to_formatted_s(:long_ordinal)  # => "November 10th, 2007 00:00"
    #
    #   date.to_formatted_s(:rfc822)            # => "10 Nov 2007"
    #   time.to_formatted_s(:rfc822)            # => "Thu, 18 Jan 2007 06:10:17 -0600"
    #   datetime.to_formatted_s(:rfc822)        # => "Sat, 10 Nov 2007 00:00:00 -0600"
    #
    #   date.to_formatted_s(:iso8601)           # => "2007-11-10"
    #   time.to_formatted_s(:iso8601)           # => "2007-01-18T06:10:17-06:00"
    #   datetime.to_formatted_s(:iso8601)       # => "2007-11-10T00:00:00-06:00"
    #
    #   date.to_formatted_s(:number)            # => "20071110"
    #   time.to_formatted_s(:number)            # => "20070118061017"
    #   datetime.to_formatted_s(:number)        # => "20071110000000"
    #
    # == Adding your own date formats to +to_formatted_s+
    # You can add your own formats to the Time::DATE_FORMATS and Date::DATE_FORMATS
    # hashes. DateTime formats are shared with Time. Use the format name as the hash
    # key and either a strftime string or Proc instance that takes a date argument
    # as the value.
    #
    #   # config/initializers/time_and_date_formats.rb
    #   Date::DATE_FORMATS[:month_and_year] = '%B %Y'
    #   Date::DATE_FORMATS[:short_ordinal] = ->(date) { date.strftime("%B #{date.day.ordinalize}") }
    #   Time::DATE_FORMATS[:month_and_year] = '%B %Y'
    #   Time::DATE_FORMATS[:short_ordinal]  = ->(time) { time.strftime("%B #{time.day.ordinalize}") }
    def to_formatted_s(format = :default)
      if formatter = self.class::DATE_FORMATS[format]
        if formatter.respond_to?(:call)
          formatter.call(self).to_s
        else
          strftime(formatter)
        end
      else
        to_default_s
      end
    end

  end
end
