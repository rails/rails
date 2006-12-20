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

      # Returns a set of select tags (one for hour, minute and optionally second) pre-selected for accessing a specified
      # time-based attribute (identified by +method+) on an object assigned to the template (identified by +object+).
      # You can include the seconds with <tt>:include_seconds</tt>.
      # Examples:
      #
      #   time_select("post", "sunrise")
      #   time_select("post", "start_time", :include_seconds => true)
      #
      # The selects are prepared for multi-parameter assignment to an Active Record object.
      def time_select(object_name, method, options = {})
        InstanceTag.new(object_name, method, self, nil, options.delete(:object)).to_time_select_tag(options)
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

      # Returns a set of html select-tags (one for year, month, day, hour, and minute) pre-selected with the +datetime+.
      # It's also possible to explicitly set the order of the tags using the <tt>:order</tt> option with an array of
      # symbols <tt>:year</tt>, <tt>:month</tt> and <tt>:day</tt> in the desired order. If you do not supply a Symbol, it
      # will be appened onto the <tt>:order</tt> passed in. You can also add <tt>:date_separator</tt> and <tt>:time_separator</tt>
      # keys to the +options+ to control visual display of the elements.
       def select_datetime(datetime = Time.now, options = {})
        separator = options[:datetime_separator] || ''
        select_date(datetime, options) + separator + select_time(datetime, options)
       end

      # Returns a set of html select-tags (one for year, month, and day) pre-selected with the +date+.
      # It's possible to explicitly set the order of the tags using the <tt>:order</tt> option with an array of
      # symbols <tt>:year</tt>, <tt>:month</tt> and <tt>:day</tt> in the desired order. If you do not supply a Symbol, it
      # will be appened onto the <tt>:order</tt> passed in.
      def select_date(date = Date.today, options = {})
        options[:order] ||= []
        [:year, :month, :day].each { |o| options[:order].push(o) unless options[:order].include?(o) }

        select_date = ''
        options[:order].each do |o|
          select_date << self.send("select_#{o}", date, options)
        end
        select_date
      end

      # Returns a set of html select-tags (one for hour and minute)
      # You can set <tt>:add_separator</tt> key to format the output.
      def select_time(datetime = Time.now, options = {})
        separator = options[:time_separator] || ''
        select_hour(datetime, options) + separator + select_minute(datetime, options) + (options[:include_seconds] ? separator + select_second(datetime, options) : '')
      end

      # Returns a select tag with options for each of the seconds 0 through 59 with the current second selected.
      # The <tt>second</tt> can also be substituted for a second number.
      # Override the field name using the <tt>:field_name</tt> option, 'second' by default.
      def select_second(datetime, options = {})
        val = datetime ? (datetime.kind_of?(Fixnum) ? datetime : datetime.sec) : ''
        if options[:use_hidden]
          options[:include_seconds] ? hidden_html(options[:field_name] || 'second', val, options) : ''
        else
          second_options = []
          0.upto(59) do |second|
            second_options << ((val == second) ?
              %(<option value="#{leading_zero_on_single_digits(second)}" selected="selected">#{leading_zero_on_single_digits(second)}</option>\n) :
              %(<option value="#{leading_zero_on_single_digits(second)}">#{leading_zero_on_single_digits(second)}</option>\n)
            )
          end
          select_html(options[:field_name] || 'second', second_options, options)
        end
      end

      # Returns a select tag with options for each of the minutes 0 through 59 with the current minute selected.
      # Also can return a select tag with options by <tt>minute_step</tt> from 0 through 59 with the 00 minute selected
      # The <tt>minute</tt> can also be substituted for a minute number.
      # Override the field name using the <tt>:field_name</tt> option, 'minute' by default.
      def select_minute(datetime, options = {})
        val = datetime ? (datetime.kind_of?(Fixnum) ? datetime : datetime.min) : ''
        if options[:use_hidden]
          hidden_html(options[:field_name] || 'minute', val, options)
        else
          minute_options = []
          0.step(59, options[:minute_step] || 1) do |minute|
            minute_options << ((val == minute) ?
              %(<option value="#{leading_zero_on_single_digits(minute)}" selected="selected">#{leading_zero_on_single_digits(minute)}</option>\n) :
              %(<option value="#{leading_zero_on_single_digits(minute)}">#{leading_zero_on_single_digits(minute)}</option>\n)
            )
          end
          select_html(options[:field_name] || 'minute', minute_options, options)
         end
      end

      # Returns a select tag with options for each of the hours 0 through 23 with the current hour selected.
      # The <tt>hour</tt> can also be substituted for a hour number.
      # Override the field name using the <tt>:field_name</tt> option, 'hour' by default.
      def select_hour(datetime, options = {})
        val = datetime ? (datetime.kind_of?(Fixnum) ? datetime : datetime.hour) : ''
        if options[:use_hidden]
          hidden_html(options[:field_name] || 'hour', val, options)
        else
          hour_options = []
          0.upto(23) do |hour|
            hour_options << ((val == hour) ?
              %(<option value="#{leading_zero_on_single_digits(hour)}" selected="selected">#{leading_zero_on_single_digits(hour)}</option>\n) :
              %(<option value="#{leading_zero_on_single_digits(hour)}">#{leading_zero_on_single_digits(hour)}</option>\n)
            )
          end
          select_html(options[:field_name] || 'hour', hour_options, options)
        end
      end

      # Returns a select tag with options for each of the days 1 through 31 with the current day selected.
      # The <tt>date</tt> can also be substituted for a hour number.
      # Override the field name using the <tt>:field_name</tt> option, 'day' by default.
      def select_day(date, options = {})
        val = date ? (date.kind_of?(Fixnum) ? date : date.day) : ''
        if options[:use_hidden]
          hidden_html(options[:field_name] || 'day', val, options)
        else
          day_options = []
          1.upto(31) do |day|
            day_options << ((val == day) ?
              %(<option value="#{day}" selected="selected">#{day}</option>\n) :
              %(<option value="#{day}">#{day}</option>\n)
            )
          end
          select_html(options[:field_name] || 'day', day_options, options)
        end
      end

      # Returns a select tag with options for each of the months January through December with the current month selected.
      # The month names are presented as keys (what's shown to the user) and the month numbers (1-12) are used as values
      # (what's submitted to the server). It's also possible to use month numbers for the presentation instead of names --
      # set the <tt>:use_month_numbers</tt> key in +options+ to true for this to happen. If you want both numbers and names,
      # set the <tt>:add_month_numbers</tt> key in +options+ to true. If you would prefer to show month names as abbreviations,
      # set the <tt>:use_short_month</tt> key in +options+ to true. If you want to use your own month names, set the
      # <tt>:use_month_names</tt> key in +options+ to an array of 12 month names.
      #
      # Examples:
      #
      #   select_month(Date.today)                             # Will use keys like "January", "March"
      #   select_month(Date.today, :use_month_numbers => true) # Will use keys like "1", "3"
      #   select_month(Date.today, :add_month_numbers => true) # Will use keys like "1 - January", "3 - March"
      #   select_month(Date.today, :use_short_month => true)   # Will use keys like "Jan", "Mar"
      #   select_month(Date.today, :use_month_names => %w(Januar Februar Marts ...))   # Will use keys like "Januar", "Marts"
      #
      # Override the field name using the <tt>:field_name</tt> option, 'month' by default.
      def select_month(date, options = {})
        val = date ? (date.kind_of?(Fixnum) ? date : date.month) : ''
        if options[:use_hidden]
          hidden_html(options[:field_name] || 'month', val, options)
        else
          month_options = []
          month_names = options[:use_month_names] || (options[:use_short_month] ? Date::ABBR_MONTHNAMES : Date::MONTHNAMES)
          month_names.unshift(nil) if month_names.size < 13
          1.upto(12) do |month_number|
            month_name = if options[:use_month_numbers]
              month_number
            elsif options[:add_month_numbers]
              month_number.to_s + ' - ' + month_names[month_number]
            else
              month_names[month_number]
            end

            month_options << ((val == month_number) ?
              %(<option value="#{month_number}" selected="selected">#{month_name}</option>\n) :
              %(<option value="#{month_number}">#{month_name}</option>\n)
            )
          end
          select_html(options[:field_name] || 'month', month_options, options)
        end
      end

      # Returns a select tag with options for each of the five years on each side of the current, which is selected. The five year radius
      # can be changed using the <tt>:start_year</tt> and <tt>:end_year</tt> keys in the +options+. Both ascending and descending year
      # lists are supported by making <tt>:start_year</tt> less than or greater than <tt>:end_year</tt>. The <tt>date</tt> can also be
      # substituted for a year given as a number. Example:
      #
      #   select_year(Date.today, :start_year => 1992, :end_year => 2007)  # ascending year values
      #   select_year(Date.today, :start_year => 2005, :end_year => 1900)  # descending year values
      #   select_year(2006, :start_year => 2000, :end_year => 2010)
      #
      # Override the field name using the <tt>:field_name</tt> option, 'year' by default.
      def select_year(date, options = {})
        val = date ? (date.kind_of?(Fixnum) ? date : date.year) : ''
        if options[:use_hidden]
          hidden_html(options[:field_name] || 'year', val, options)
        else
          year_options = []
          y = date ? (date.kind_of?(Fixnum) ? (y = (date == 0) ? Date.today.year : date) : date.year) : Date.today.year

          start_year, end_year = (options[:start_year] || y-5), (options[:end_year] || y+5)
          step_val = start_year < end_year ? 1 : -1
          start_year.step(end_year, step_val) do |year|
            year_options << ((val == year) ?
              %(<option value="#{year}" selected="selected">#{year}</option>\n) :
              %(<option value="#{year}">#{year}</option>\n)
            )
          end
          select_html(options[:field_name] || 'year', year_options, options)
        end
      end

      private

        def select_html(type, html_options, options)
          name_and_id_from_options(options, type)
          select_html  = %(<select id="#{options[:id]}" name="#{options[:name]}")
          select_html << %( disabled="disabled") if options[:disabled]
          select_html << %(>\n)
          select_html << %(<option value=""></option>\n) if options[:include_blank]
          select_html << html_options.to_s
          select_html << "</select>\n"
        end

        def hidden_html(type, value, options)
          name_and_id_from_options(options, type)
          hidden_html = %(<input type="hidden" id="#{options[:id]}" name="#{options[:name]}" value="#{value}" />\n)
        end

        def name_and_id_from_options(options, type)
          options[:name] = (options[:prefix] || DEFAULT_PREFIX) + (options[:discard_type] ? '' : "[#{type}]")
          options[:id] = options[:name].gsub(/([\[\(])|(\]\[)/, '_').gsub(/[\]\)]/, '')
        end

        def leading_zero_on_single_digits(number)
          number > 9 ? number : "0#{number}"
        end
    end

    class InstanceTag #:nodoc:
      include DateHelper

      def to_date_select_tag(options = {})
        date_or_time_select options.merge(:discard_hour => true)
      end

      def to_time_select_tag(options = {})
        date_or_time_select options.merge(:discard_year => true, :discard_month => true)
      end

      def to_datetime_select_tag(options = {})
        date_or_time_select options
      end

      private
        def date_or_time_select(options)
          defaults = { :discard_type => true }
          options  = defaults.merge(options)
          datetime = value(object)
          datetime ||= Time.now unless options[:include_blank]

          position = { :year => 1, :month => 2, :day => 3, :hour => 4, :minute => 5, :second => 6 }

          order = (options[:order] ||= [:year, :month, :day])

          # Discard explicit and implicit by not being included in the :order
          discard = {}
          discard[:year]   = true if options[:discard_year] or !order.include?(:year)
          discard[:month]  = true if options[:discard_month] or !order.include?(:month)
          discard[:day]    = true if options[:discard_day] or discard[:month] or !order.include?(:day)
          discard[:hour]   = true if options[:discard_hour]
          discard[:minute] = true if options[:discard_minute] or discard[:hour]
          discard[:second] = true unless options[:include_seconds] && !discard[:minute]

          # Maintain valid dates by including hidden fields for discarded elements
          [:day, :month, :year].each { |o| order.unshift(o) unless order.include?(o) }
          # Ensure proper ordering of :hour, :minute and :second
          [:hour, :minute, :second].each { |o| order.delete(o); order.push(o) }

          date_or_time_select = ''
          order.reverse.each do |param|
            # Send hidden fields for discarded elements once output has started
            # This ensures AR can reconstruct valid dates using ParseDate
            next if discard[param] && date_or_time_select.empty?

            date_or_time_select.insert(0, self.send("select_#{param}", datetime, options_with_prefix(position[param], options.merge(:use_hidden => discard[param]))))
            date_or_time_select.insert(0,
              case param
                when :hour then (discard[:year] && discard[:day] ? "" : " &mdash; ")
                when :minute then " : "
                when :second then options[:include_seconds] ? " : " : ""
                else ""
              end)

          end

          date_or_time_select
        end

        def options_with_prefix(position, options)
          prefix = "#{@object_name}"
          if options[:index]
            prefix << "[#{options[:index]}]"
          elsif @auto_index
            prefix << "[#{@auto_index}]"
          end
          options.merge(:prefix => "#{prefix}[#{@method_name}(#{position}i)]")
        end
    end

    class FormBuilder
      def date_select(method, options = {})
        @template.date_select(@object_name, method, options.merge(:object => @object))
      end

      def time_select(method, options = {})
        @template.time_select(@object_name, method, options.merge(:object => @object))
      end

      def datetime_select(method, options = {})
        @template.datetime_select(@object_name, method, options.merge(:object => @object))
      end
    end
  end
end
