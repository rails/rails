require "date"

module ActionView
  module Helpers
    # The Date Helper primarily creates select/option tags for different kinds of dates and date elements. All of the select-type methods
    # share a number of common options that are as follows:
    #
    # * <tt>:prefix</tt> - overwrites the default prefix of "date" used for the select names. So specifying "birthday" would give 
    #   birthday[month] instead of date[month] if passed to the select_month method.
    # * <tt>:include_blank</tt> - set to true if it should be possible to set an empty date.
    # * <tt>:discard_type</tt> - set to true if you want to discard the type part of the select name. If set to true, the select_month
    #   method would use simply "date" (which can be overwritten using <tt>:prefix</tt>) instead of "date[month]".
    module DateHelper
      DEFAULT_PREFIX = "date" unless const_defined?("DEFAULT_PREFIX")

      # Reports the approximate distance in time between to Time objects. For example, if the distance is 47 minutes, it'll return 
      # "about 1 hour". See the source for the complete wording list.
      def distance_of_time_in_words(from_time, to_time)
        distance_in_minutes = ((to_time - from_time) / 60).round
        
        case distance_in_minutes
          when 0..45      then "#{distance_in_minutes} minutes"
          when 46..90     then "about 1 hour"
          when 90..1440   then "about #{(distance_in_minutes.to_f / 60.0).round} hours"
          when 1441..2880 then "1 day"
          else                 "#{(distance_in_minutes / 1440).round} days"
        end
      end

      # Returns a set of select tags (one for year, month, and day) pre-selected for accessing a specified date-based attribute (identified by
      # +method+) on an object assigned to the template (identified by +object+). Examples:
      #
      #   date_select("post", "written_on")
      #   date_select("post", "written_on", :start_year => 1995)
      #
      # The selects are prepared for multi-parameter assignment to an Active Record object.
      def date_select(object, method, options = {})
        InstanceTag.new(object, method, binding).to_date_select_tag(options)
      end

      # Returns a set of select tags (one for year, month, day, hour, and minute) pre-selected for accessing a specified datetime-based
      # attribute (identified by +method+) on an object assigned to the template (identified by +object+). Examples:
      #
      #   datetime_select("post", "written_on")
      #   datetime_select("post", "written_on", :start_year => 1995)
      #
      # The selects are prepared for multi-parameter assignment to an Active Record object.
      def datetime_select(object, method, options = {})
        InstanceTag.new(object, method, binding).to_datetime_select_tag(options)
      end

      # Returns a set of html select-tags (one for year, month, and day) pre-selected with the +date+.
      def select_date(date = Date.today, options = {})
        select_day(date, options) + select_month(date, options) + select_year(date, options)
      end

      # Returns a set of html select-tags (one for year, month, day, hour, and minute) preselected the +datetime+.
      def select_datetime(datetime = Time.now, options = {})
        select_year(datetime, options) + select_month(datetime, options) + select_day(datetime, options) +
        select_hour(datetime, options) + select_minute(datetime, options)
      end

      # Returns a select tag with options for each of the minutes 0 through 59 with the current minute selected.
      # The <tt>minute</tt> can also be substituted for a minute number.
      def select_minute(datetime, options = {})
        minute_options = []

        0.upto(59) do |minute|
          minute_options << ((datetime.kind_of?(Fixnum) ? datetime : datetime.min) == minute ?
            "<option selected>#{leading_zero_on_single_digits(minute)}</option>\n" : 
            "<option>#{leading_zero_on_single_digits(minute)}</option>\n"
          )
        end

        select_html("minute", minute_options, options[:prefix], options[:include_blank], options[:discard_type])
      end

      # Returns a select tag with options for each of the hours 0 through 23 with the current hour selected.
      # The <tt>hour</tt> can also be substituted for a hour number.
      def select_hour(datetime, options = {})
        hour_options = []

        0.upto(23) do |hour|
          hour_options << ((datetime.kind_of?(Fixnum) ? datetime : datetime.hour) == hour ?
            "<option selected>#{leading_zero_on_single_digits(hour)}</option>\n" : 
            "<option>#{leading_zero_on_single_digits(hour)}</option>\n"
          )
        end

        select_html("hour", hour_options, options[:prefix], options[:include_blank], options[:discard_type])
      end

      # Returns a select tag with options for each of the days 1 through 31 with the current day selected.
      # The <tt>date</tt> can also be substituted for a hour number.
      def select_day(date, options = {})
        day_options = []

        1.upto(31) do |day|
          day_options << ((date.kind_of?(Fixnum) ? date : date.day) == day ?
            "<option selected>#{day}</option>\n" : 
            "<option>#{day}</option>\n"
          )
        end

        select_html("day", day_options, options[:prefix], options[:include_blank], options[:discard_type])
      end
      
      # Returns a select tag with options for each of the months January through December with the current month selected.
      # The month names are presented as keys (what's shown to the user) and the month numbers (1-12) are used as values
      # (what's submitted to the server). It's also possible to use month numbers for the presentation instead of names --
      # set the <tt>:use_month_numbers</tt> key in +options+ to true for this to happen. The <tt>date</tt> can also be substituted 
      # for a month number. Example:
      #
      #   select_month(Date.today, :use_month_numbers => true)
      def select_month(date, options = {})
        month_options = []

        1.upto(12) do |month_number|
          month_name = options[:use_month_numbers] ? month_number : Date::MONTHNAMES[month_number]
          month_options << ((date.kind_of?(Fixnum) ? date : date.month) == month_number ?
            "<option value='#{month_number}' selected>#{month_name}</option>\n" : 
            "<option value='#{month_number}'>#{month_name}</option>\n"
          )
        end

        select_html("month", month_options, options[:prefix], options[:include_blank], options[:discard_type])
      end
      
      # Returns a select tag with options for each of the five years on each side of the current, which is selected. The five year radius
      # can be changed using the <tt>:start_year</tt> and <tt>:end_year</tt> keys in the +options+. The <tt>date</tt> can also be substituted 
      # for a year given as a number. Example:
      #
      #   select_year(Date.today, :start_year => 1992, :end_year => 2007)
      def select_year(date, options = {})
        year_options = []
        unless date.kind_of?(Fixnum) then default_start_year, default_end_year = date.year - 5, date.year + 5 end

        (options[:start_year] || default_start_year).upto(options[:end_year] || default_end_year) do |year|
          year_options << ((date.kind_of?(Fixnum) ? date : date.year) == year ?
            "<option selected>#{year}</option>\n" : 
            "<option>#{year}</option>\n"
          )
        end

        select_html("year", year_options, options[:prefix], options[:include_blank], options[:discard_type])
      end
      
      private
        def select_html(type, options, prefix = nil, include_blank = false, discard_type = false)
          select_html  = "<select name='#{prefix || DEFAULT_PREFIX}"
          select_html << "[#{type}]" unless discard_type
          select_html << "'>\n"
          select_html << "<option></option>\n" if include_blank
          select_html << options.to_s
          select_html << "</select>\n"

          return select_html
        end
        
        def leading_zero_on_single_digits(number)
          number > 9 ? number : "0#{number}"
        end
    end

    class InstanceTag #:nodoc:
      include DateHelper

      def to_date_select_tag(options = {})
        defaults = { :discard_type => true }
        date     = value || Date.today
        options  = Proc.new { |position| defaults.update({ :prefix => "#{@object_name}[#{@method_name}(#{position}i)]" }) }

        select_year(date, options.call(1)) +
        select_month(date, options.call(2)) +
        select_day(date, options.call(3))
      end
      
      def to_datetime_select_tag(options = {})
        defaults = { :discard_type => true }
        datetime = value || Time.now
        options  = Proc.new { |position| defaults.update({ :prefix => "#{@object_name}[#{@method_name}(#{position}i)]" }) }

        select_year(datetime, options.call(1)) +
        select_month(datetime, options.call(2)) +
        select_day(datetime, options.call(3)) + " &mdash; " +
        select_hour(datetime, options.call(4)) + " : " +
        select_minute(datetime, options.call(5))
      end
    end
  end
end