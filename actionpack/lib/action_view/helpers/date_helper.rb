require "date"
require 'action_view/helpers/tag_helper'

module ActionView
  module Helpers
    # The Date Helper primarily creates select/option tags for different kinds of dates and date elements. All of the
    # select-type methods share a number of common options that are as follows:
    #
    # * <tt>:prefix</tt> - overwrites the default prefix of "date" used for the select names. So specifying "birthday"
    # would give birthday[month] instead of date[month] if passed to the select_month method.
    # * <tt>:include_blank</tt> - set to true if it should be possible to set an empty date.
    # * <tt>:discard_type</tt> - set to true if you want to discard the type part of the select name. If set to true,
    #   the select_month method would use simply "date" (which can be overwritten using <tt>:prefix</tt>) instead of
    #   "date[month]".
    module DateHelper
      # Reports the approximate distance in time between two Time or Date objects or integers as seconds.
      # Set <tt>include_seconds</tt> to true if you want more detailed approximations when distance < 1 min, 29 secs
      # Distances are reported based on the following table:
      #
      #   0 <-> 29 secs                                                             # => less than a minute
      #   30 secs <-> 1 min, 29 secs                                                # => 1 minute
      #   1 min, 30 secs <-> 44 mins, 29 secs                                       # => [2..44] minutes
      #   44 mins, 30 secs <-> 89 mins, 29 secs                                     # => about 1 hour
      #   89 mins, 29 secs <-> 23 hrs, 59 mins, 29 secs                             # => about [2..24] hours
      #   23 hrs, 59 mins, 29 secs <-> 47 hrs, 59 mins, 29 secs                     # => 1 day
      #   47 hrs, 59 mins, 29 secs <-> 29 days, 23 hrs, 59 mins, 29 secs            # => [2..29] days
      #   29 days, 23 hrs, 59 mins, 30 secs <-> 59 days, 23 hrs, 59 mins, 29 secs   # => about 1 month
      #   59 days, 23 hrs, 59 mins, 30 secs <-> 1 yr minus 1 sec                    # => [2..12] months
      #   1 yr <-> 1 yr, 3 months                                                   # => about 1 year
      #   1 yr, 3 months <-> 1 yr, 9 months                                         # => over 1 year
      #   1 yr, 9 months <-> 2 yr minus 1 sec                                       # => almost 2 years
      #   2 yrs <-> max time or date                                                # => (same rules as 1 yr)
      #
      # With <tt>include_seconds</tt> = true and the difference < 1 minute 29 seconds:
      #   0-4   secs      # => less than 5 seconds
      #   5-9   secs      # => less than 10 seconds
      #   10-19 secs      # => less than 20 seconds
      #   20-39 secs      # => half a minute
      #   40-59 secs      # => less than a minute
      #   60-89 secs      # => 1 minute
      #
      # ==== Examples
      #   from_time = Time.now
      #   distance_of_time_in_words(from_time, from_time + 50.minutes)        # => about 1 hour
      #   distance_of_time_in_words(from_time, 50.minutes.from_now)           # => about 1 hour
      #   distance_of_time_in_words(from_time, from_time + 15.seconds)        # => less than a minute
      #   distance_of_time_in_words(from_time, from_time + 15.seconds, true)  # => less than 20 seconds
      #   distance_of_time_in_words(from_time, 3.years.from_now)              # => about 3 years
      #   distance_of_time_in_words(from_time, from_time + 60.hours)          # => about 3 days
      #   distance_of_time_in_words(from_time, from_time + 45.seconds, true)  # => less than a minute
      #   distance_of_time_in_words(from_time, from_time - 45.seconds, true)  # => less than a minute
      #   distance_of_time_in_words(from_time, 76.seconds.from_now)           # => 1 minute
      #   distance_of_time_in_words(from_time, from_time + 1.year + 3.days)   # => about 1 year
      #   distance_of_time_in_words(from_time, from_time + 3.years + 6.months) # => over 3 years
      #   distance_of_time_in_words(from_time, from_time + 4.years + 9.days + 30.minutes + 5.seconds) # => about 4 years
      #
      #   to_time = Time.now + 6.years + 19.days
      #   distance_of_time_in_words(from_time, to_time, true)     # => about 6 years
      #   distance_of_time_in_words(to_time, from_time, true)     # => about 6 years
      #   distance_of_time_in_words(Time.now, Time.now)           # => less than a minute
      #
      def distance_of_time_in_words(from_time, to_time = 0, include_seconds = false, options = {})
        from_time = from_time.to_time if from_time.respond_to?(:to_time)
        to_time = to_time.to_time if to_time.respond_to?(:to_time)
        distance_in_minutes = (((to_time - from_time).abs)/60).round
        distance_in_seconds = ((to_time - from_time).abs).round

        I18n.with_options :locale => options[:locale], :scope => :'datetime.distance_in_words' do |locale|
          case distance_in_minutes
            when 0..1
              return distance_in_minutes == 0 ?
                     locale.t(:less_than_x_minutes, :count => 1) :
                     locale.t(:x_minutes, :count => distance_in_minutes) unless include_seconds

              case distance_in_seconds
                when 0..4   then locale.t :less_than_x_seconds, :count => 5
                when 5..9   then locale.t :less_than_x_seconds, :count => 10
                when 10..19 then locale.t :less_than_x_seconds, :count => 20
                when 20..39 then locale.t :half_a_minute
                when 40..59 then locale.t :less_than_x_minutes, :count => 1
                else             locale.t :x_minutes,           :count => 1
              end

            when 2..44           then locale.t :x_minutes,      :count => distance_in_minutes
            when 45..89          then locale.t :about_x_hours,  :count => 1
            when 90..1439        then locale.t :about_x_hours,  :count => (distance_in_minutes.to_f / 60.0).round
            when 1440..2529      then locale.t :x_days,         :count => 1
            when 2530..43199     then locale.t :x_days,         :count => (distance_in_minutes.to_f / 1440.0).round
            when 43200..86399    then locale.t :about_x_months, :count => 1
            when 86400..525599   then locale.t :x_months,       :count => (distance_in_minutes.to_f / 43200.0).round
            else
              distance_in_years           = distance_in_minutes / 525600
              minute_offset_for_leap_year = (distance_in_years / 4) * 1440
              remainder                   = ((distance_in_minutes - minute_offset_for_leap_year) % 525600)
              if remainder < 131400
                locale.t(:about_x_years,  :count => distance_in_years)
              elsif remainder < 394200
                locale.t(:over_x_years,   :count => distance_in_years)
              else
                locale.t(:almost_x_years, :count => distance_in_years + 1)
              end
          end
        end
      end

      # Like distance_of_time_in_words, but where <tt>to_time</tt> is fixed to <tt>Time.now</tt>.
      #
      # ==== Examples
      #   time_ago_in_words(3.minutes.from_now)       # => 3 minutes
      #   time_ago_in_words(Time.now - 15.hours)      # => 15 hours
      #   time_ago_in_words(Time.now)                 # => less than a minute
      #
      #   from_time = Time.now - 3.days - 14.minutes - 25.seconds     # => 3 days
      def time_ago_in_words(from_time, include_seconds = false)
        distance_of_time_in_words(from_time, Time.now, include_seconds)
      end

      alias_method :distance_of_time_in_words_to_now, :time_ago_in_words

      # Returns a set of select tags (one for year, month, and day) pre-selected for accessing a specified date-based
      # attribute (identified by +method+) on an object assigned to the template (identified by +object+). You can
      # the output in the +options+ hash.
      #
      # ==== Options
      # * <tt>:use_month_numbers</tt> - Set to true if you want to use month numbers rather than month names (e.g.
      #   "2" instead of "February").
      # * <tt>:use_short_month</tt>   - Set to true if you want to use the abbreviated month name instead of the full
      #   name (e.g. "Feb" instead of "February").
      # * <tt>:add_month_number</tt>  - Set to true if you want to show both, the month's number and name (e.g.
      #   "2 - February" instead of "February").
      # * <tt>:use_month_names</tt>   - Set to an array with 12 month names if you want to customize month names.
      #   Note: You can also use Rails' new i18n functionality for this.
      # * <tt>:date_separator</tt>    - Specifies a string to separate the date fields. Default is "" (i.e. nothing).
      # * <tt>:start_year</tt>        - Set the start year for the year select. Default is <tt>Time.now.year - 5</tt>.
      # * <tt>:end_year</tt>          - Set the end year for the year select. Default is <tt>Time.now.year + 5</tt>.
      # * <tt>:discard_day</tt>       - Set to true if you don't want to show a day select. This includes the day
      #   as a hidden field instead of showing a select field. Also note that this implicitly sets the day to be the
      #   first of the given month in order to not create invalid dates like 31 February.
      # * <tt>:discard_month</tt>     - Set to true if you don't want to show a month select. This includes the month
      #   as a hidden field instead of showing a select field. Also note that this implicitly sets :discard_day to true.
      # * <tt>:discard_year</tt>      - Set to true if you don't want to show a year select. This includes the year
      #   as a hidden field instead of showing a select field.
      # * <tt>:order</tt>             - Set to an array containing <tt>:day</tt>, <tt>:month</tt> and <tt>:year</tt> do
      #   customize the order in which the select fields are shown. If you leave out any of the symbols, the respective
      #   select will not be shown (like when you set <tt>:discard_xxx => true</tt>. Defaults to the order defined in
      #   the respective locale (e.g. [:year, :month, :day] in the en locale that ships with Rails).
      # * <tt>:include_blank</tt>     - Include a blank option in every select field so it's possible to set empty
      #   dates.
      # * <tt>:default</tt>           - Set a default date if the affected date isn't set or is nil.
      # * <tt>:disabled</tt>          - Set to true if you want show the select fields as disabled.
      # * <tt>:prompt</tt>            - Set to true (for a generic prompt), a prompt string or a hash of prompt strings
      #   for <tt>:year</tt>, <tt>:month</tt>, <tt>:day</tt>, <tt>:hour</tt>, <tt>:minute</tt> and <tt>:second</tt>.
      #   Setting this option prepends a select option with a generic prompt  (Day, Month, Year, Hour, Minute, Seconds)
      #   or the given prompt string.
      #
      # If anything is passed in the +html_options+ hash it will be applied to every select tag in the set.
      #
      # NOTE: Discarded selects will default to 1. So if no month select is available, January will be assumed.
      #
      # ==== Examples
      #   # Generates a date select that when POSTed is stored in the post variable, in the written_on attribute
      #   date_select("post", "written_on")
      #
      #   # Generates a date select that when POSTed is stored in the post variable, in the written_on attribute,
      #   # with the year in the year drop down box starting at 1995.
      #   date_select("post", "written_on", :start_year => 1995)
      #
      #   # Generates a date select that when POSTed is stored in the post variable, in the written_on attribute,
      #   # with the year in the year drop down box starting at 1995, numbers used for months instead of words,
      #   # and without a day select box.
      #   date_select("post", "written_on", :start_year => 1995, :use_month_numbers => true,
      #                                     :discard_day => true, :include_blank => true)
      #
      #   # Generates a date select that when POSTed is stored in the post variable, in the written_on attribute
      #   # with the fields ordered as day, month, year rather than month, day, year.
      #   date_select("post", "written_on", :order => [:day, :month, :year])
      #
      #   # Generates a date select that when POSTed is stored in the user variable, in the birthday attribute
      #   # lacking a year field.
      #   date_select("user", "birthday", :order => [:month, :day])
      #
      #   # Generates a date select that when POSTed is stored in the user variable, in the birthday attribute
      #   # which is initially set to the date 3 days from the current date
      #   date_select("post", "written_on", :default => 3.days.from_now)
      #
      #   # Generates a date select that when POSTed is stored in the credit_card variable, in the bill_due attribute
      #   # that will have a default day of 20.
      #   date_select("credit_card", "bill_due", :default => { :day => 20 })
      #
      #   # Generates a date select with custom prompts
      #   date_select("post", "written_on", :prompt => { :day => 'Select day', :month => 'Select month', :year => 'Select year' })
      #
      # The selects are prepared for multi-parameter assignment to an Active Record object.
      #
      # Note: If the day is not included as an option but the month is, the day will be set to the 1st to ensure that
      # all month choices are valid.
      def date_select(object_name, method, options = {}, html_options = {})
        InstanceTag.new(object_name, method, self, options.delete(:object)).to_date_select_tag(options, html_options)
      end

      # Returns a set of select tags (one for hour, minute and optionally second) pre-selected for accessing a
      # specified time-based attribute (identified by +method+) on an object assigned to the template (identified by
      # +object+). You can include the seconds with <tt>:include_seconds</tt>.
      #
      # This method will also generate 3 input hidden tags, for the actual year, month and day unless the option
      # <tt>:ignore_date</tt> is set to +true+.
      #
      # If anything is passed in the html_options hash it will be applied to every select tag in the set.
      #
      # ==== Examples
      #   # Creates a time select tag that, when POSTed, will be stored in the post variable in the sunrise attribute
      #   time_select("post", "sunrise")
      #
      #   # Creates a time select tag that, when POSTed, will be stored in the order variable in the submitted
      #   # attribute
      #   time_select("order", "submitted")
      #
      #   # Creates a time select tag that, when POSTed, will be stored in the mail variable in the sent_at attribute
      #   time_select("mail", "sent_at")
      #
      #   # Creates a time select tag with a seconds field that, when POSTed, will be stored in the post variables in
      #   # the sunrise attribute.
      #   time_select("post", "start_time", :include_seconds => true)
      #
      #   # Creates a time select tag with a seconds field that, when POSTed, will be stored in the entry variables in
      #   # the submission_time attribute.
      #   time_select("entry", "submission_time", :include_seconds => true)
      #
      #   # You can set the :minute_step to 15 which will give you: 00, 15, 30 and 45.
      #   time_select 'game', 'game_time', {:minute_step => 15}
      #
      #   # Creates a time select tag with a custom prompt. Use :prompt => true for generic prompts.
      #   time_select("post", "written_on", :prompt => {:hour => 'Choose hour', :minute => 'Choose minute', :second => 'Choose seconds'})
      #   time_select("post", "written_on", :prompt => {:hour => true}) # generic prompt for hours
      #   time_select("post", "written_on", :prompt => true) # generic prompts for all
      #
      # The selects are prepared for multi-parameter assignment to an Active Record object.
      #
      # Note: If the day is not included as an option but the month is, the day will be set to the 1st to ensure that
      # all month choices are valid.
      def time_select(object_name, method, options = {}, html_options = {})
        InstanceTag.new(object_name, method, self, options.delete(:object)).to_time_select_tag(options, html_options)
      end

      # Returns a set of select tags (one for year, month, day, hour, and minute) pre-selected for accessing a
      # specified datetime-based attribute (identified by +method+) on an object assigned to the template (identified
      # by +object+). Examples:
      #
      # If anything is passed in the html_options hash it will be applied to every select tag in the set.
      #
      # ==== Examples
      #   # Generates a datetime select that, when POSTed, will be stored in the post variable in the written_on
      #   # attribute
      #   datetime_select("post", "written_on")
      #
      #   # Generates a datetime select with a year select that starts at 1995 that, when POSTed, will be stored in the
      #   # post variable in the written_on attribute.
      #   datetime_select("post", "written_on", :start_year => 1995)
      #
      #   # Generates a datetime select with a default value of 3 days from the current time that, when POSTed, will
      #   # be stored in the trip variable in the departing attribute.
      #   datetime_select("trip", "departing", :default => 3.days.from_now)
      #
      #   # Generates a datetime select that discards the type that, when POSTed, will be stored in the post variable
      #   # as the written_on attribute.
      #   datetime_select("post", "written_on", :discard_type => true)
      #
      #   # Generates a datetime select with a custom prompt. Use :prompt=>true for generic prompts.
      #   datetime_select("post", "written_on", :prompt => {:day => 'Choose day', :month => 'Choose month', :year => 'Choose year'})
      #   datetime_select("post", "written_on", :prompt => {:hour => true}) # generic prompt for hours
      #   datetime_select("post", "written_on", :prompt => true) # generic prompts for all
      #
      # The selects are prepared for multi-parameter assignment to an Active Record object.
      def datetime_select(object_name, method, options = {}, html_options = {})
        InstanceTag.new(object_name, method, self, options.delete(:object)).to_datetime_select_tag(options, html_options)
      end

      # Returns a set of html select-tags (one for year, month, day, hour, and minute) pre-selected with the
      # +datetime+. It's also possible to explicitly set the order of the tags using the <tt>:order</tt> option with
      # an array of symbols <tt>:year</tt>, <tt>:month</tt> and <tt>:day</tt> in the desired order. If you do not
      # supply a Symbol, it will be appended onto the <tt>:order</tt> passed in. You can also add
      # <tt>:date_separator</tt>, <tt>:datetime_separator</tt> and <tt>:time_separator</tt> keys to the +options+ to
      # control visual display of the elements.
      #
      # If anything is passed in the html_options hash it will be applied to every select tag in the set.
      #
      # ==== Examples
      #   my_date_time = Time.now + 4.days
      #
      #   # Generates a datetime select that defaults to the datetime in my_date_time (four days after today)
      #   select_datetime(my_date_time)
      #
      #   # Generates a datetime select that defaults to today (no specified datetime)
      #   select_datetime()
      #
      #   # Generates a datetime select that defaults to the datetime in my_date_time (four days after today)
      #   # with the fields ordered year, month, day rather than month, day, year.
      #   select_datetime(my_date_time, :order => [:year, :month, :day])
      #
      #   # Generates a datetime select that defaults to the datetime in my_date_time (four days after today)
      #   # with a '/' between each date field.
      #   select_datetime(my_date_time, :date_separator => '/')
      #
      #   # Generates a datetime select that defaults to the datetime in my_date_time (four days after today)
      #   # with a date fields separated by '/', time fields separated by '' and the date and time fields
      #   # separated by a comma (',').
      #   select_datetime(my_date_time, :date_separator => '/', :time_separator => '', :datetime_separator => ',')
      #
      #   # Generates a datetime select that discards the type of the field and defaults to the datetime in
      #   # my_date_time (four days after today)
      #   select_datetime(my_date_time, :discard_type => true)
      #
      #   # Generates a datetime select that defaults to the datetime in my_date_time (four days after today)
      #   # prefixed with 'payday' rather than 'date'
      #   select_datetime(my_date_time, :prefix => 'payday')
      #
      #   # Generates a datetime select with a custom prompt. Use :prompt=>true for generic prompts.
      #   select_datetime(my_date_time, :prompt => {:day => 'Choose day', :month => 'Choose month', :year => 'Choose year'})
      #   select_datetime(my_date_time, :prompt => {:hour => true}) # generic prompt for hours
      #   select_datetime(my_date_time, :prompt => true) # generic prompts for all
      #
      def select_datetime(datetime = Time.current, options = {}, html_options = {})
        DateTimeSelector.new(datetime, options, html_options).select_datetime
      end

      # Returns a set of html select-tags (one for year, month, and day) pre-selected with the +date+.
      # It's possible to explicitly set the order of the tags using the <tt>:order</tt> option with an array of
      # symbols <tt>:year</tt>, <tt>:month</tt> and <tt>:day</tt> in the desired order. If you do not supply a Symbol,
      # it will be appended onto the <tt>:order</tt> passed in.
      #
      # If anything is passed in the html_options hash it will be applied to every select tag in the set.
      #
      # ==== Examples
      #   my_date = Time.today + 6.days
      #
      #   # Generates a date select that defaults to the date in my_date (six days after today)
      #   select_date(my_date)
      #
      #   # Generates a date select that defaults to today (no specified date)
      #   select_date()
      #
      #   # Generates a date select that defaults to the date in my_date (six days after today)
      #   # with the fields ordered year, month, day rather than month, day, year.
      #   select_date(my_date, :order => [:year, :month, :day])
      #
      #   # Generates a date select that discards the type of the field and defaults to the date in
      #   # my_date (six days after today)
      #   select_date(my_date, :discard_type => true)
      #
      #   # Generates a date select that defaults to the date in my_date,
      #   # which has fields separated by '/'
      #   select_date(my_date, :date_separator => '/')
      #
      #   # Generates a date select that defaults to the datetime in my_date (six days after today)
      #   # prefixed with 'payday' rather than 'date'
      #   select_date(my_date, :prefix => 'payday')
      #
      #   # Generates a date select with a custom prompt. Use :prompt=>true for generic prompts.
      #   select_date(my_date, :prompt => {:day => 'Choose day', :month => 'Choose month', :year => 'Choose year'})
      #   select_date(my_date, :prompt => {:hour => true}) # generic prompt for hours
      #   select_date(my_date, :prompt => true) # generic prompts for all
      #
      def select_date(date = Date.current, options = {}, html_options = {})
        DateTimeSelector.new(date, options, html_options).select_date
      end

      # Returns a set of html select-tags (one for hour and minute)
      # You can set <tt>:time_separator</tt> key to format the output, and
      # the <tt>:include_seconds</tt> option to include an input for seconds.
      #
      # If anything is passed in the html_options hash it will be applied to every select tag in the set.
      #
      # ==== Examples
      #   my_time = Time.now + 5.days + 7.hours + 3.minutes + 14.seconds
      #
      #   # Generates a time select that defaults to the time in my_time
      #   select_time(my_time)
      #
      #   # Generates a time select that defaults to the current time (no specified time)
      #   select_time()
      #
      #   # Generates a time select that defaults to the time in my_time,
      #   # which has fields separated by ':'
      #   select_time(my_time, :time_separator => ':')
      #
      #   # Generates a time select that defaults to the time in my_time,
      #   # that also includes an input for seconds
      #   select_time(my_time, :include_seconds => true)
      #
      #   # Generates a time select that defaults to the time in my_time, that has fields
      #   # separated by ':' and includes an input for seconds
      #   select_time(my_time, :time_separator => ':', :include_seconds => true)
      #
      #   # Generates a time select with a custom prompt. Use :prompt=>true for generic prompts.
      #   select_time(my_time, :prompt => {:day => 'Choose day', :month => 'Choose month', :year => 'Choose year'})
      #   select_time(my_time, :prompt => {:hour => true}) # generic prompt for hours
      #   select_time(my_time, :prompt => true) # generic prompts for all
      #
      def select_time(datetime = Time.current, options = {}, html_options = {})
        DateTimeSelector.new(datetime, options, html_options).select_time
      end

      # Returns a select tag with options for each of the seconds 0 through 59 with the current second selected.
      # The <tt>second</tt> can also be substituted for a second number.
      # Override the field name using the <tt>:field_name</tt> option, 'second' by default.
      #
      # ==== Examples
      #   my_time = Time.now + 16.minutes
      #
      #   # Generates a select field for seconds that defaults to the seconds for the time in my_time
      #   select_second(my_time)
      #
      #   # Generates a select field for seconds that defaults to the number given
      #   select_second(33)
      #
      #   # Generates a select field for seconds that defaults to the seconds for the time in my_time
      #   # that is named 'interval' rather than 'second'
      #   select_second(my_time, :field_name => 'interval')
      #
      #   # Generates a select field for seconds with a custom prompt.  Use :prompt=>true for a
      #   # generic prompt.
      #   select_minute(14, :prompt => 'Choose seconds')
      #
      def select_second(datetime, options = {}, html_options = {})
        DateTimeSelector.new(datetime, options, html_options).select_second
      end

      # Returns a select tag with options for each of the minutes 0 through 59 with the current minute selected.
      # Also can return a select tag with options by <tt>minute_step</tt> from 0 through 59 with the 00 minute
      # selected. The <tt>minute</tt> can also be substituted for a minute number.
      # Override the field name using the <tt>:field_name</tt> option, 'minute' by default.
      #
      # ==== Examples
      #   my_time = Time.now + 6.hours
      #
      #   # Generates a select field for minutes that defaults to the minutes for the time in my_time
      #   select_minute(my_time)
      #
      #   # Generates a select field for minutes that defaults to the number given
      #   select_minute(14)
      #
      #   # Generates a select field for minutes that defaults to the minutes for the time in my_time
      #   # that is named 'stride' rather than 'second'
      #   select_minute(my_time, :field_name => 'stride')
      #
      #   # Generates a select field for minutes with a custom prompt.  Use :prompt=>true for a
      #   # generic prompt.
      #   select_minute(14, :prompt => 'Choose minutes')
      #
      def select_minute(datetime, options = {}, html_options = {})
        DateTimeSelector.new(datetime, options, html_options).select_minute
      end

      # Returns a select tag with options for each of the hours 0 through 23 with the current hour selected.
      # The <tt>hour</tt> can also be substituted for a hour number.
      # Override the field name using the <tt>:field_name</tt> option, 'hour' by default.
      #
      # ==== Examples
      #   my_time = Time.now + 6.hours
      #
      #   # Generates a select field for hours that defaults to the hour for the time in my_time
      #   select_hour(my_time)
      #
      #   # Generates a select field for hours that defaults to the number given
      #   select_hour(13)
      #
      #   # Generates a select field for hours that defaults to the minutes for the time in my_time
      #   # that is named 'stride' rather than 'second'
      #   select_hour(my_time, :field_name => 'stride')
      #
      #   # Generates a select field for hours with a custom prompt.  Use :prompt => true for a
      #   # generic prompt.
      #   select_hour(13, :prompt =>'Choose hour')
      #
      def select_hour(datetime, options = {}, html_options = {})
        DateTimeSelector.new(datetime, options, html_options).select_hour
      end

      # Returns a select tag with options for each of the days 1 through 31 with the current day selected.
      # The <tt>date</tt> can also be substituted for a hour number.
      # Override the field name using the <tt>:field_name</tt> option, 'day' by default.
      #
      # ==== Examples
      #   my_date = Time.today + 2.days
      #
      #   # Generates a select field for days that defaults to the day for the date in my_date
      #   select_day(my_time)
      #
      #   # Generates a select field for days that defaults to the number given
      #   select_day(5)
      #
      #   # Generates a select field for days that defaults to the day for the date in my_date
      #   # that is named 'due' rather than 'day'
      #   select_day(my_time, :field_name => 'due')
      #
      #   # Generates a select field for days with a custom prompt.  Use :prompt => true for a
      #   # generic prompt.
      #   select_day(5, :prompt => 'Choose day')
      #
      def select_day(date, options = {}, html_options = {})
        DateTimeSelector.new(date, options, html_options).select_day
      end

      # Returns a select tag with options for each of the months January through December with the current month
      # selected. The month names are presented as keys (what's shown to the user) and the month numbers (1-12) are
      # used as values (what's submitted to the server). It's also possible to use month numbers for the presentation
      # instead of names -- set the <tt>:use_month_numbers</tt> key in +options+ to true for this to happen. If you
      # want both numbers and names, set the <tt>:add_month_numbers</tt> key in +options+ to true. If you would prefer
      # to show month names as abbreviations, set the <tt>:use_short_month</tt> key in +options+ to true. If you want
      # to use your own month names, set the <tt>:use_month_names</tt> key in +options+ to an array of 12 month names.
      # Override the field name using the <tt>:field_name</tt> option, 'month' by default.
      #
      # ==== Examples
      #   # Generates a select field for months that defaults to the current month that
      #   # will use keys like "January", "March".
      #   select_month(Date.today)
      #
      #   # Generates a select field for months that defaults to the current month that
      #   # is named "start" rather than "month"
      #   select_month(Date.today, :field_name => 'start')
      #
      #   # Generates a select field for months that defaults to the current month that
      #   # will use keys like "1", "3".
      #   select_month(Date.today, :use_month_numbers => true)
      #
      #   # Generates a select field for months that defaults to the current month that
      #   # will use keys like "1 - January", "3 - March".
      #   select_month(Date.today, :add_month_numbers => true)
      #
      #   # Generates a select field for months that defaults to the current month that
      #   # will use keys like "Jan", "Mar".
      #   select_month(Date.today, :use_short_month => true)
      #
      #   # Generates a select field for months that defaults to the current month that
      #   # will use keys like "Januar", "Marts."
      #   select_month(Date.today, :use_month_names => %w(Januar Februar Marts ...))
      #
      #   # Generates a select field for months with a custom prompt.  Use :prompt => true for a
      #   # generic prompt.
      #   select_month(14, :prompt => 'Choose month')
      #
      def select_month(date, options = {}, html_options = {})
        DateTimeSelector.new(date, options, html_options).select_month
      end

      # Returns a select tag with options for each of the five years on each side of the current, which is selected.
      # The five year radius can be changed using the <tt>:start_year</tt> and <tt>:end_year</tt> keys in the
      # +options+. Both ascending and descending year lists are supported by making <tt>:start_year</tt> less than or
      # greater than <tt>:end_year</tt>. The <tt>date</tt> can also be substituted for a year given as a number.
      # Override the field name using the <tt>:field_name</tt> option, 'year' by default.
      #
      # ==== Examples
      #   # Generates a select field for years that defaults to the current year that
      #   # has ascending year values
      #   select_year(Date.today, :start_year => 1992, :end_year => 2007)
      #
      #   # Generates a select field for years that defaults to the current year that
      #   # is named 'birth' rather than 'year'
      #   select_year(Date.today, :field_name => 'birth')
      #
      #   # Generates a select field for years that defaults to the current year that
      #   # has descending year values
      #   select_year(Date.today, :start_year => 2005, :end_year => 1900)
      #
      #   # Generates a select field for years that defaults to the year 2006 that
      #   # has ascending year values
      #   select_year(2006, :start_year => 2000, :end_year => 2010)
      #
      #   # Generates a select field for years with a custom prompt.  Use :prompt => true for a
      #   # generic prompt.
      #   select_year(14, :prompt => 'Choose year')
      #
      def select_year(date, options = {}, html_options = {})
        DateTimeSelector.new(date, options, html_options).select_year
      end
    end

    class DateTimeSelector #:nodoc:
      extend ActiveSupport::Memoizable
      include ActionView::Helpers::TagHelper

      DEFAULT_PREFIX = 'date'.freeze unless const_defined?('DEFAULT_PREFIX')
      POSITION = {
        :year => 1, :month => 2, :day => 3, :hour => 4, :minute => 5, :second => 6
      }.freeze unless const_defined?('POSITION')

      def initialize(datetime, options = {}, html_options = {})
        @options      = options.dup
        @html_options = html_options.dup
        @datetime     = datetime
      end

      def select_datetime
        # TODO: Remove tag conditional
        # Ideally we could just join select_date and select_date for the tag case
        if @options[:tag] && @options[:ignore_date]
          select_time
        elsif @options[:tag]
          order = date_order.dup
          order -= [:hour, :minute, :second]

          @options[:discard_year]   ||= true unless order.include?(:year)
          @options[:discard_month]  ||= true unless order.include?(:month)
          @options[:discard_day]    ||= true if @options[:discard_month] || !order.include?(:day)
          @options[:discard_minute] ||= true if @options[:discard_hour]
          @options[:discard_second] ||= true unless @options[:include_seconds] && !@options[:discard_minute]

          # If the day is hidden and the month is visible, the day should be set to the 1st so all month choices are
          # valid (otherwise it could be 31 and february wouldn't be a valid date)
          if @datetime && @options[:discard_day] && !@options[:discard_month]
            @datetime = @datetime.change(:day => 1)
          end

          [:day, :month, :year].each { |o| order.unshift(o) unless order.include?(o) }
          order += [:hour, :minute, :second] unless @options[:discard_hour]

          build_selects_from_types(order)
        else
          "#{select_date}#{@options[:datetime_separator]}#{select_time}"
        end
      end

      def select_date
        order = date_order.dup

        # TODO: Remove tag conditional
        if @options[:tag]
          @options[:discard_hour]     = true
          @options[:discard_minute]   = true
          @options[:discard_second]   = true

          @options[:discard_year]   ||= true unless order.include?(:year)
          @options[:discard_month]  ||= true unless order.include?(:month)
          @options[:discard_day]    ||= true if @options[:discard_month] || !order.include?(:day)

          # If the day is hidden and the month is visible, the day should be set to the 1st so all month choices are
          # valid (otherwise it could be 31 and february wouldn't be a valid date)
          if @datetime && @options[:discard_day] && !@options[:discard_month]
            @datetime = @datetime.change(:day => 1)
          end
        end

        [:day, :month, :year].each { |o| order.unshift(o) unless order.include?(o) }

        build_selects_from_types(order)
      end

      def select_time
        order = []

        # TODO: Remove tag conditional
        if @options[:tag]
          @options[:discard_month]    = true
          @options[:discard_year]     = true
          @options[:discard_day]      = true
          @options[:discard_second] ||= true unless @options[:include_seconds]

          order += [:year, :month, :day] unless @options[:ignore_date]
        end

        order += [:hour, :minute]
        order << :second if @options[:include_seconds]

        build_selects_from_types(order)
      end

      def select_second
        if @options[:use_hidden] || @options[:discard_second]
          build_hidden(:second, sec) if @options[:include_seconds]
        else
          build_options_and_select(:second, sec)
        end
      end

      def select_minute
        if @options[:use_hidden] || @options[:discard_minute]
          build_hidden(:minute, min)
        else
          build_options_and_select(:minute, min, :step => @options[:minute_step])
        end
      end

      def select_hour
        if @options[:use_hidden] || @options[:discard_hour]
          build_hidden(:hour, hour)
        else
          build_options_and_select(:hour, hour, :end => 23)
        end
      end

      def select_day
        if @options[:use_hidden] || @options[:discard_day]
          build_hidden(:day, day)
        else
          build_options_and_select(:day, day, :start => 1, :end => 31, :leading_zeros => false)
        end
      end

      def select_month
        if @options[:use_hidden] || @options[:discard_month]
          build_hidden(:month, month)
        else
          month_options = []
          1.upto(12) do |month_number|
            options = { :value => month_number }
            options[:selected] = "selected" if month == month_number
            month_options << content_tag(:option, month_name(month_number), options) + "\n"
          end
          build_select(:month, month_options.join)
        end
      end

      def select_year
        if !@datetime || @datetime == 0
          val = ''
          middle_year = Date.today.year
        else
          val = middle_year = year
        end

        if @options[:use_hidden] || @options[:discard_year]
          build_hidden(:year, val)
        else
          options                 = {}
          options[:start]         = @options[:start_year] || middle_year - 5
          options[:end]           = @options[:end_year] || middle_year + 5
          options[:step]          = options[:start] < options[:end] ? 1 : -1
          options[:leading_zeros] = false

          build_options_and_select(:year, val, options)
        end
      end

      private
        %w( sec min hour day month year ).each do |method|
          define_method(method) do
            @datetime.kind_of?(Fixnum) ? @datetime : @datetime.send(method) if @datetime
          end
        end

        # Returns translated month names, but also ensures that a custom month
        # name array has a leading nil element
        def month_names
          month_names = @options[:use_month_names] || translated_month_names
          month_names.unshift(nil) if month_names.size < 13
          month_names
        end
        memoize :month_names

        # Returns translated month names
        #  => [nil, "January", "February", "March",
        #           "April", "May", "June", "July",
        #           "August", "September", "October",
        #           "November", "December"]
        #
        # If :use_short_month option is set
        #  => [nil, "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        #           "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        def translated_month_names
          begin
            key = @options[:use_short_month] ? :'date.abbr_month_names' : :'date.month_names'
            I18n.translate(key, :locale => @options[:locale])
          end
        end

        # Lookup month name for number
        #  month_name(1) => "January"
        #
        # If :use_month_numbers option is passed
        #  month_name(1) => 1
        #
        # If :add_month_numbers option is passed
        #  month_name(1) => "1 - January"
        def month_name(number)
          if @options[:use_month_numbers]
            number
          elsif @options[:add_month_numbers]
            "#{number} - #{month_names[number]}"
          else
            month_names[number]
          end
        end

        def date_order
          @options[:order] || translated_date_order
        end
        memoize :date_order

        def translated_date_order
          begin
            I18n.translate(:'date.order', :locale => @options[:locale]) || []
          end
        end

        # Build full select tag from date type and options
        def build_options_and_select(type, selected, options = {})
          build_select(type, build_options(selected, options))
        end

        # Build select option html from date value and options
        #  build_options(15, :start => 1, :end => 31)
        #  => "<option value="1">1</option>
        #      <option value=\"2\">2</option>
        #      <option value=\"3\">3</option>..."
        def build_options(selected, options = {})
          start         = options.delete(:start) || 0
          stop          = options.delete(:end) || 59
          step          = options.delete(:step) || 1
          leading_zeros = options.delete(:leading_zeros).nil? ? true : false

          select_options = []
          start.step(stop, step) do |i|
            value = leading_zeros ? sprintf("%02d", i) : i
            tag_options = { :value => value }
            tag_options[:selected] = "selected" if selected == i
            select_options << content_tag(:option, value, tag_options)
          end
          select_options.join("\n") + "\n"
        end

        # Builds select tag from date type and html select options
        #  build_select(:month, "<option value="1">January</option>...")
        #  => "<select id="post_written_on_2i" name="post[written_on(2i)]">
        #        <option value="1">January</option>...
        #      </select>"
        def build_select(type, select_options_as_html)
          select_options = {
            :id => input_id_from_type(type),
            :name => input_name_from_type(type)
          }.merge(@html_options)
          select_options.merge!(:disabled => 'disabled') if @options[:disabled]

          select_html = "\n"
          select_html << content_tag(:option, '', :value => '') + "\n" if @options[:include_blank]
          select_html << prompt_option_tag(type, @options[:prompt]) + "\n" if @options[:prompt]
          select_html << select_options_as_html.to_s

          content_tag(:select, select_html, select_options) + "\n"
        end

        # Builds a prompt option tag with supplied options or from default options
        #  prompt_option_tag(:month, :prompt => 'Select month')
        #  => "<option value="">Select month</option>"
        def prompt_option_tag(type, options)
          default_options = {:year => false, :month => false, :day => false, :hour => false, :minute => false, :second => false}

          case options
          when Hash
            prompt = default_options.merge(options)[type.to_sym]
          when String
            prompt = options
          else
            prompt = I18n.translate(('datetime.prompts.' + type.to_s).to_sym, :locale => @options[:locale])
          end

          prompt ? content_tag(:option, prompt, :value => '') : ''
        end

        # Builds hidden input tag for date part and value
        #  build_hidden(:year, 2008)
        #  => "<input id="post_written_on_1i" name="post[written_on(1i)]" type="hidden" value="2008" />"
        def build_hidden(type, value)
          tag(:input, {
            :type => "hidden",
            :id => input_id_from_type(type),
            :name => input_name_from_type(type),
            :value => value
          }) + "\n"
        end

        # Returns the name attribute for the input tag
        #  => post[written_on(1i)]
        def input_name_from_type(type)
          prefix = @options[:prefix] || ActionView::Helpers::DateTimeSelector::DEFAULT_PREFIX
          prefix += "[#{@options[:index]}]" if @options.has_key?(:index)

          field_name = @options[:field_name] || type
          if @options[:include_position]
            field_name += "(#{ActionView::Helpers::DateTimeSelector::POSITION[type]}i)"
          end

          @options[:discard_type] ? prefix : "#{prefix}[#{field_name}]"
        end

        # Returns the id attribute for the input tag
        #  => "post_written_on_1i"
        def input_id_from_type(type)
          input_name_from_type(type).gsub(/([\[\(])|(\]\[)/, '_').gsub(/[\]\)]/, '')
        end

        # Given an ordering of datetime components, create the selection HTML
        # and join them with their appropriate separators.
        def build_selects_from_types(order)
          select = ''
          order.reverse.each do |type|
            separator = separator(type) unless type == order.first # don't add on last field
            select.insert(0, separator.to_s + send("select_#{type}").to_s)
          end
          select
        end

        # Returns the separator for a given datetime component
        def separator(type)
          case type
            when :month, :day
              @options[:date_separator]
            when :hour
              (@options[:discard_year] && @options[:discard_day]) ? "" : @options[:datetime_separator]
            when :minute
              @options[:time_separator]
            when :second
              @options[:include_seconds] ? @options[:time_separator] : ""
          end
        end
    end

    class InstanceTag #:nodoc:
      def to_date_select_tag(options = {}, html_options = {})
        datetime_selector(options, html_options).select_date.html_safe!
      end

      def to_time_select_tag(options = {}, html_options = {})
        datetime_selector(options, html_options).select_time.html_safe!
      end

      def to_datetime_select_tag(options = {}, html_options = {})
        datetime_selector(options, html_options).select_datetime.html_safe!
      end

      private
        def datetime_selector(options, html_options)
          datetime = value(object) || default_datetime(options)

          options = options.dup
          options[:field_name]           = @method_name
          options[:include_position]     = true
          options[:prefix]             ||= @object_name
          options[:index]                = @auto_index if @auto_index && !options.has_key?(:index)
          options[:datetime_separator] ||= ' &mdash; '
          options[:time_separator]     ||= ' : '

          DateTimeSelector.new(datetime, options.merge(:tag => true), html_options)
        end

        def default_datetime(options)
          return if options[:include_blank] || options[:prompt]

          case options[:default]
            when nil
              Time.current
            when Date, Time
              options[:default]
            else
              default = options[:default].dup

              # Rename :minute and :second to :min and :sec
              default[:min] ||= default[:minute]
              default[:sec] ||= default[:second]

              time = Time.current

              [:year, :month, :day, :hour, :min, :sec].each do |key|
                default[key] ||= time.send(key)
              end

              Time.utc_time(
                default[:year], default[:month], default[:day],
                default[:hour], default[:min], default[:sec]
              )
          end
        end
    end

    class FormBuilder
      def date_select(method, options = {}, html_options = {})
        @template.date_select(@object_name, method, objectify_options(options), html_options)
      end

      def time_select(method, options = {}, html_options = {})
        @template.time_select(@object_name, method, objectify_options(options), html_options)
      end

      def datetime_select(method, options = {}, html_options = {})
        @template.datetime_select(@object_name, method, objectify_options(options), html_options)
      end
    end
  end
end
