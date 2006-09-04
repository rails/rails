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
      DEFAULT_PREFIX = 'date' unless const_defined?('DEFAULT_PREFIX')

      # Reports the approximate distance in time between two Time or Date objects or integers as seconds.
      # Set <tt>include_seconds</tt> to true if you want more detailed approximations when distance < 1 min, 29 secs
      # Distances are reported base on the following table:
      #
      # 0 <-> 29 secs                                                             # => less than a minute
      # 30 secs <-> 1 min, 29 secs                                                # => 1 minute
      # 1 min, 30 secs <-> 44 mins, 29 secs                                       # => [2..44] minutes
      # 44 mins, 30 secs <-> 89 mins, 29 secs                                     # => about 1 hour
      # 89 mins, 29 secs <-> 23 hrs, 59 mins, 29 secs                             # => about [2..24] hours
      # 23 hrs, 59 mins, 29 secs <-> 47 hrs, 59 mins, 29 secs                     # => 1 day
      # 47 hrs, 59 mins, 29 secs <-> 29 days, 23 hrs, 59 mins, 29 secs            # => [2..29] days
      # 29 days, 23 hrs, 59 mins, 30 secs <-> 59 days, 23 hrs, 59 mins, 29 secs   # => about 1 month
      # 59 days, 23 hrs, 59 mins, 30 secs <-> 1 yr minus 31 secs                  # => [2..12] months
      # 1 yr minus 30 secs <-> 2 yrs minus 31 secs                                # => about 1 year
      # 2 yrs minus 30 secs <-> max time or date                                  # => over [2..X] years
      #
      # With include_seconds = true and the difference < 1 minute 29 seconds
      # 0-4   secs      # => less than 5 seconds
      # 5-9   secs      # => less than 10 seconds
      # 10-19 secs      # => less than 20 seconds
      # 20-39 secs      # => half a minute
      # 40-59 secs      # => less than a minute
      # 60-89 secs      # => 1 minute
      #
      # Examples:
      #
      #   from_time = Time.now
      #   distance_of_time_in_words(from_time, from_time + 50.minutes) # => about 1 hour
      #   distance_of_time_in_words(from_time, from_time + 15.seconds) # => less than a minute
      #   distance_of_time_in_words(from_time, from_time + 15.seconds, true) # => less than 20 seconds
      #
      # Note: Rails calculates one year as 365.25 days.
      def distance_of_time_in_words(from_time, to_time = 0, include_seconds = false)
        from_time = from_time.to_time if from_time.respond_to?(:to_time)
        to_time = to_time.to_time if to_time.respond_to?(:to_time)
        distance_in_minutes = (((to_time - from_time).abs)/60).round
        distance_in_seconds = ((to_time - from_time).abs).round

        case distance_in_minutes
          when 0..1
            return (distance_in_minutes == 0) ? 'less than a minute' : '1 minute' unless include_seconds
            case distance_in_seconds
              when 0..4   then 'less than 5 seconds'
              when 5..9   then 'less than 10 seconds'
              when 10..19 then 'less than 20 seconds'
              when 20..39 then 'half a minute'
              when 40..59 then 'less than a minute'
              else             '1 minute'
            end
                                
          when 2..44           then "#{distance_in_minutes} minutes"
          when 45..89          then 'about 1 hour'
          when 90..1439        then "about #{(distance_in_minutes.to_f / 60.0).round} hours"
          when 1440..2879      then '1 day'
          when 2880..43199     then "#{(distance_in_minutes / 1440).round} days"
          when 43200..86399    then 'about 1 month'
          when 86400..525959   then "#{(distance_in_minutes / 43200).round} months"
          when 525960..1051919 then 'about 1 year'
          else                      "over #{(distance_in_minutes / 525960).round} years"
        end
      end
      
      # Like distance_of_time_in_words, but where <tt>to_time</tt> is fixed to <tt>Time.now</tt>.
      def time_ago_in_words(from_time, include_seconds = false)
        distance_of_time_in_words(from_time, Time.now, include_seconds)
      end
      
      alias_method :distance_of_time_in_words_to_now, :time_ago_in_words

      # Returns a set of select tags (one for year, month, and day) pre-selected for accessing a specified date-based attribute (identified by
      # +method+) on an object assigned to the template (identified by +object+). It's possible to tailor the selects through the +options+ hash,
      # which accepts all the keys that each of the individual select builders do (like :use_month_numbers for select_month) as well as a range of
      # discard options. The discard options are <tt>:discard_year</tt>, <tt>:discard_month</tt> and <tt>:discard_day</tt>. Set to true, they'll
      # drop the respective select. Discarding the month select will also automatically discard the day select. It's also possible to explicitly
      # set the order of the tags using the <tt>:order</tt> option with an array of symbols <tt>:year</tt>, <tt>:month</tt> and <tt>:day</tt> in
      # the desired order. Symbols may be omitted and the respective select is not included.
      #
      # Passing :disabled => true as part of the +options+ will make elements inaccessible for change.
      #
      # NOTE: Discarded selects will default to 1. So if no month select is available, January will be assumed.
      #
      # Examples:
      #
      #   date_select("post", "written_on")
      #   date_select("post", "written_on", :start_year => 1995)
      #   date_select("post", "written_on", :start_year => 1995, :use_month_numbers => true,
      #                                     :discard_day => true, :include_blank => true)
      #   date_select("post", "written_on", :order => [:day, :month, :year])
      #   date_select("user", "birthday",   :order => [:month, :day])
      #
      # The selects are prepared for multi-parameter assignment to an Active Record object.
      def date_select(object_name, method, options = {})
        InstanceTag.new(object_name, method, self, nil, options.delete(:object)).to_date_select_tag(options)
      end

      # Returns a set of select tags (one for year, month, day, hour, and minute) pre-selected for accessing a specified datetime-based
      # attribute (identified by +method+) on an object assigned to the template (identified by +object+). Examples:
      #
      #   datetime_select("post", "written_on")
      #   datetime_select("post", "written_on", :start_year => 1995)
      #
      # The selects are prepared for multi-parameter assignment to an Active Record object.
      def datetime_select(object_name, method, options = {})
        InstanceTag.new(object_name, method, self, nil, options.delete(:object)).to_datetime_select_tag(options)
      end

      # Returns a set of html select-tags (one for year, month, and day) pre-selected with the +date+.
      def select_date(date = Date.today, options = {})
        select_year(date, options) + select_month(date, options) + select_day(date, options)
      end

      # Returns a set of html select-tags (one for year, month, day, hour, and minute) pre-selected with the +datetime+.
      def select_datetime(datetime = Time.now, options = {})
        select_year(datetime, options) + select_month(datetime, options) + select_day(datetime, options) +
        select_hour(datetime, options) + select_minute(datetime, options)
      end

      # Returns a set of html select-tags (one for hour and minute)
      def select_time(datetime = Time.now, options = {})
        h = select_hour(datetime, options) + select_minute(datetime, options) + (options[:include_seconds] ? select_second(datetime, options) : '')
      end

      # Returns a select tag with options for each of the seconds 0 through 59 with the current second selected.
      # The <tt>second</tt> can also be substituted for a second number.
      # Override the field name using the <tt>:field_name</tt> option, 'second' by default.
      def select_second(datetime, options = {})
        second_options = []

        0.upto(59) do |second|
          second_options << ((datetime && (datetime.kind_of?(Fixnum) ? datetime : datetime.sec) == second) ?
            %(<option value="#{leading_zero_on_single_digits(second)}" selected="selected">#{leading_zero_on_single_digits(second)}</option>\n) :
            %(<option value="#{leading_zero_on_single_digits(second)}">#{leading_zero_on_single_digits(second)}</option>\n)
          )
        end

        select_html(options[:field_name] || 'second', second_options, options[:prefix], options[:include_blank], options[:discard_type], options[:disabled])
      end

      # Returns a select tag with options for each of the minutes 0 through 59 with the current minute selected.
      # Also can return a select tag with options by <tt>minute_step</tt> from 0 through 59 with the 00 minute selected
      # The <tt>minute</tt> can also be substituted for a minute number.
      # Override the field name using the <tt>:field_name</tt> option, 'minute' by default.
      def select_minute(datetime, options = {})
        minute_options = []

        0.step(59, options[:minute_step] || 1) do |minute|
          minute_options << ((datetime && (datetime.kind_of?(Fixnum) ? datetime : datetime.min) == minute) ?
            %(<option value="#{leading_zero_on_single_digits(minute)}" selected="selected">#{leading_zero_on_single_digits(minute)}</option>\n) :
            %(<option value="#{leading_zero_on_single_digits(minute)}">#{leading_zero_on_single_digits(minute)}</option>\n)
          )
        end

        select_html(options[:field_name] || 'minute', minute_options, options[:prefix], options[:include_blank], options[:discard_type], options[:disabled])
      end

      # Returns a select tag with options for each of the hours 0 through 23 with the current hour selected.
      # The <tt>hour</tt> can also be substituted for a hour number.
      # Override the field name using the <tt>:field_name</tt> option, 'hour' by default.
      def select_hour(datetime, options = {})
        hour_options = []

        0.upto(23) do |hour|
          hour_options << ((datetime && (datetime.kind_of?(Fixnum) ? datetime : datetime.hour) == hour) ?
            %(<option value="#{leading_zero_on_single_digits(hour)}" selected="selected">#{leading_zero_on_single_digits(hour)}</option>\n) :
            %(<option value="#{leading_zero_on_single_digits(hour)}">#{leading_zero_on_single_digits(hour)}</option>\n)
          )
        end

        select_html(options[:field_name] || 'hour', hour_options, options[:prefix], options[:include_blank], options[:discard_type], options[:disabled])
      end

      # Returns a select tag with options for each of the days 1 through 31 with the current day selected.
      # The <tt>date</tt> can also be substituted for a hour number.
      # Override the field name using the <tt>:field_name</tt> option, 'day' by default.
      def select_day(date, options = {})
        day_options = []

        1.upto(31) do |day|
          day_options << ((date && (date.kind_of?(Fixnum) ? date : date.day) == day) ?
            %(<option value="#{day}" selected="selected">#{day}</option>\n) :
            %(<option value="#{day}">#{day}</option>\n)
          )
        end

        select_html(options[:field_name] || 'day', day_options, options[:prefix], options[:include_blank], options[:discard_type], options[:disabled])
      end

      # Returns a select tag with options for each of the months January through December with the current month selected.
      # The month names are presented as keys (what's shown to the user) and the month numbers (1-12) are used as values
      # (what's submitted to the server). It's also possible to use month numbers for the presentation instead of names --
      # set the <tt>:use_month_numbers</tt> key in +options+ to true for this to happen. If you want both numbers and names,
      # set the <tt>:add_month_numbers</tt> key in +options+ to true. Examples:
      #
      #   select_month(Date.today)                             # Will use keys like "January", "March"
      #   select_month(Date.today, :use_month_numbers => true) # Will use keys like "1", "3"
      #   select_month(Date.today, :add_month_numbers => true) # Will use keys like "1 - January", "3 - March"
      #
      # Override the field name using the <tt>:field_name</tt> option, 'month' by default.
      #
      # If you would prefer to show month names as abbreviations, set the
      # <tt>:use_short_month</tt> key in +options+ to true.
      def select_month(date, options = {})
        month_options = []
        month_names = options[:use_short_month] ? Date::ABBR_MONTHNAMES : Date::MONTHNAMES

        1.upto(12) do |month_number|
          month_name = if options[:use_month_numbers]
            month_number
          elsif options[:add_month_numbers]
            month_number.to_s + ' - ' + month_names[month_number]
          else
            month_names[month_number]
          end

          month_options << ((date && (date.kind_of?(Fixnum) ? date : date.month) == month_number) ?
            %(<option value="#{month_number}" selected="selected">#{month_name}</option>\n) :
            %(<option value="#{month_number}">#{month_name}</option>\n)
          )
        end

        select_html(options[:field_name] || 'month', month_options, options[:prefix], options[:include_blank], options[:discard_type], options[:disabled])
      end

      # Returns a select tag with options for each of the five years on each side of the current, which is selected. The five year radius
      # can be changed using the <tt>:start_year</tt> and <tt>:end_year</tt> keys in the +options+. Both ascending and descending year
      # lists are supported by making <tt>:start_year</tt> less than or greater than <tt>:end_year</tt>. The <tt>date</tt> can also be
      # substituted for a year given as a number. Example:
      #
      #   select_year(Date.today, :start_year => 1992, :end_year => 2007)  # ascending year values
      #   select_year(Date.today, :start_year => 2005, :end_year => 1900)  # descending year values
      #
      # Override the field name using the <tt>:field_name</tt> option, 'year' by default.
      def select_year(date, options = {})
        year_options = []
        y = date ? (date.kind_of?(Fixnum) ? (y = (date == 0) ? Date.today.year : date) : date.year) : Date.today.year

        start_year, end_year = (options[:start_year] || y-5), (options[:end_year] || y+5)
        step_val = start_year < end_year ? 1 : -1

        start_year.step(end_year, step_val) do |year|
          year_options << ((date && (date.kind_of?(Fixnum) ? date : date.year) == year) ?
            %(<option value="#{year}" selected="selected">#{year}</option>\n) :
            %(<option value="#{year}">#{year}</option>\n)
          )
        end

        select_html(options[:field_name] || 'year', year_options, options[:prefix], options[:include_blank], options[:discard_type], options[:disabled])
      end

      private
        def select_html(type, options, prefix = nil, include_blank = false, discard_type = false, disabled = false)
          select_html  = %(<select name="#{prefix || DEFAULT_PREFIX})
          select_html << "[#{type}]" unless discard_type
          select_html << %(")
          select_html << %( disabled="disabled") if disabled
          select_html << %(>\n)
          select_html << %(<option value=""></option>\n) if include_blank
          select_html << options.to_s
          select_html << "</select>\n"
        end

        def leading_zero_on_single_digits(number)
          number > 9 ? number : "0#{number}"
        end
    end

    class InstanceTag #:nodoc:
      include DateHelper

      def to_date_select_tag(options = {})
        defaults = { :discard_type => true }
        options  = defaults.merge(options)
        options_with_prefix = Proc.new { |position| options.merge(:prefix => "#{@object_name}[#{@method_name}(#{position}i)]") }
        value = value(object)
        date     = options[:include_blank] ? (value || 0) : (value || Date.today)

        date_select = ''
        options[:order]   = [:month, :year, :day] if options[:month_before_year] # For backwards compatibility
        options[:order] ||= [:year, :month, :day]

        position = {:year => 1, :month => 2, :day => 3}

        discard = {}
        discard[:year]  = true if options[:discard_year]
        discard[:month] = true if options[:discard_month]
        discard[:day]   = true if options[:discard_day] or options[:discard_month]

        options[:order].each do |param|
          date_select << self.send("select_#{param}", date, options_with_prefix.call(position[param])) unless discard[param]
        end

        date_select
      end

      def to_datetime_select_tag(options = {})
        defaults = { :discard_type => true }
        options  = defaults.merge(options)
        options_with_prefix = Proc.new { |position| options.merge(:prefix => "#{@object_name}[#{@method_name}(#{position}i)]") }
        value = value(object)
        datetime = options[:include_blank] ? (value || nil) : (value || Time.now)

        datetime_select  = select_year(datetime, options_with_prefix.call(1))
        datetime_select << select_month(datetime, options_with_prefix.call(2)) unless options[:discard_month]
        datetime_select << select_day(datetime, options_with_prefix.call(3)) unless options[:discard_day] || options[:discard_month]
        datetime_select << ' &mdash; ' + select_hour(datetime, options_with_prefix.call(4)) unless options[:discard_hour]
        datetime_select << ' : ' + select_minute(datetime, options_with_prefix.call(5)) unless options[:discard_minute] || options[:discard_hour]

        datetime_select
      end
    end

    class FormBuilder
      def date_select(method, options = {})
        @template.date_select(@object_name, method, options.merge(:object => @object))
      end

      def datetime_select(method, options = {})
        @template.datetime_select(@object_name, method, options.merge(:object => @object))
      end
    end
  end
end
