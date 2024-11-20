# frozen_string_literal: true

require "date"
require "action_view/helpers/tag_helper"
require "active_support/core_ext/array/extract_options"
require "active_support/core_ext/date/conversions"
require "active_support/core_ext/hash/slice"
require "active_support/core_ext/object/acts_like"
require "active_support/core_ext/object/with_options"

module ActionView
  module Helpers # :nodoc:
    # = Action View \Date \Helpers
    #
    # The Date Helper primarily creates select/option tags for different kinds of dates and times or date and time
    # elements. All of the select-type methods share a number of common options that are as follows:
    #
    # * <tt>:prefix</tt> - overwrites the default prefix of "date" used for the select names. So specifying "birthday"
    #   would give \birthday[month] instead of \date[month] if passed to the <tt>select_month</tt> method.
    # * <tt>:include_blank</tt> - set to true if it should be possible to set an empty date.
    # * <tt>:discard_type</tt> - set to true if you want to discard the type part of the select name. If set to true,
    #   the <tt>select_month</tt> method would use simply "date" (which can be overwritten using <tt>:prefix</tt>) instead
    #   of \date[month].
    module DateHelper
      MINUTES_IN_YEAR = 525600
      MINUTES_IN_QUARTER_YEAR = 131400
      MINUTES_IN_THREE_QUARTERS_YEAR = 394200

      # Reports the approximate distance in time between two Time, Date, or DateTime objects or integers as seconds.
      # Pass <tt>include_seconds: true</tt> if you want more detailed approximations when distance < 1 min, 29 secs.
      # Distances are reported based on the following table:
      #
      #   0 <-> 29 secs                                                             # => less than a minute
      #   30 secs <-> 1 min, 29 secs                                                # => 1 minute
      #   1 min, 30 secs <-> 44 mins, 29 secs                                       # => [2..44] minutes
      #   44 mins, 30 secs <-> 89 mins, 29 secs                                     # => about 1 hour
      #   89 mins, 30 secs <-> 23 hrs, 59 mins, 29 secs                             # => about [2..24] hours
      #   23 hrs, 59 mins, 30 secs <-> 41 hrs, 59 mins, 29 secs                     # => 1 day
      #   41 hrs, 59 mins, 30 secs  <-> 29 days, 23 hrs, 59 mins, 29 secs           # => [2..29] days
      #   29 days, 23 hrs, 59 mins, 30 secs <-> 44 days, 23 hrs, 59 mins, 29 secs   # => about 1 month
      #   44 days, 23 hrs, 59 mins, 30 secs <-> 59 days, 23 hrs, 59 mins, 29 secs   # => about 2 months
      #   59 days, 23 hrs, 59 mins, 30 secs <-> 1 yr minus 1 sec                    # => [2..12] months
      #   1 yr <-> 1 yr, 3 months                                                   # => about 1 year
      #   1 yr, 3 months <-> 1 yr, 9 months                                         # => over 1 year
      #   1 yr, 9 months <-> 2 yr minus 1 sec                                       # => almost 2 years
      #   2 yrs <-> max time or date                                                # => (same rules as 1 yr)
      #
      # With <tt>include_seconds: true</tt> and the difference < 1 minute 29 seconds:
      #   0-4   secs      # => less than 5 seconds
      #   5-9   secs      # => less than 10 seconds
      #   10-19 secs      # => less than 20 seconds
      #   20-39 secs      # => half a minute
      #   40-59 secs      # => less than a minute
      #   60-89 secs      # => 1 minute
      #
      #   from_time = Time.now
      #   distance_of_time_in_words(from_time, from_time + 50.minutes)                                # => about 1 hour
      #   distance_of_time_in_words(from_time, 50.minutes.from_now)                                   # => about 1 hour
      #   distance_of_time_in_words(from_time, from_time + 15.seconds)                                # => less than a minute
      #   distance_of_time_in_words(from_time, from_time + 15.seconds, include_seconds: true)         # => less than 20 seconds
      #   distance_of_time_in_words(from_time, 3.years.from_now)                                      # => about 3 years
      #   distance_of_time_in_words(from_time, from_time + 60.hours)                                  # => 3 days
      #   distance_of_time_in_words(from_time, from_time + 45.seconds, include_seconds: true)         # => less than a minute
      #   distance_of_time_in_words(from_time, from_time - 45.seconds, include_seconds: true)         # => less than a minute
      #   distance_of_time_in_words(from_time, 76.seconds.from_now)                                   # => 1 minute
      #   distance_of_time_in_words(from_time, from_time + 1.year + 3.days)                           # => about 1 year
      #   distance_of_time_in_words(from_time, from_time + 3.years + 6.months)                        # => over 3 years
      #   distance_of_time_in_words(from_time, from_time + 4.years + 9.days + 30.minutes + 5.seconds) # => about 4 years
      #
      #   to_time = Time.now + 6.years + 19.days
      #   distance_of_time_in_words(from_time, to_time, include_seconds: true)                        # => about 6 years
      #   distance_of_time_in_words(to_time, from_time, include_seconds: true)                        # => about 6 years
      #   distance_of_time_in_words(Time.now, Time.now)                                               # => less than a minute
      #
      # With the <tt>scope</tt> option, you can define a custom scope for \Rails
      # to look up the translation.
      #
      # For example you can define the following in your locale (e.g. en.yml).
      #
      #   datetime:
      #     distance_in_words:
      #       short:
      #         about_x_hours:
      #           one: 'an hour'
      #           other: '%{count} hours'
      #
      # See https://github.com/svenfuchs/rails-i18n/blob/master/rails/locale/en.yml
      # for more examples.
      #
      # Which will then result in the following:
      #
      #   from_time = Time.now
      #   distance_of_time_in_words(from_time, from_time + 50.minutes, scope: 'datetime.distance_in_words.short') # => "an hour"
      #   distance_of_time_in_words(from_time, from_time + 3.hours, scope: 'datetime.distance_in_words.short')    # => "3 hours"
      def distance_of_time_in_words(from_time, to_time = 0, options = {})
        options = {
          scope: :'datetime.distance_in_words'
        }.merge!(options)

        from_time = normalize_distance_of_time_argument_to_time(from_time)
        to_time = normalize_distance_of_time_argument_to_time(to_time)
        from_time, to_time = to_time, from_time if from_time > to_time
        distance_in_minutes = ((to_time - from_time) / 60.0).round
        distance_in_seconds = (to_time - from_time).round

        I18n.with_options locale: options[:locale], scope: options[:scope] do |locale|
          case distance_in_minutes
          when 0..1
            return distance_in_minutes == 0 ?
                   locale.t(:less_than_x_minutes, count: 1) :
                   locale.t(:x_minutes, count: distance_in_minutes) unless options[:include_seconds]

            case distance_in_seconds
            when 0..4   then locale.t :less_than_x_seconds, count: 5
            when 5..9   then locale.t :less_than_x_seconds, count: 10
            when 10..19 then locale.t :less_than_x_seconds, count: 20
            when 20..39 then locale.t :half_a_minute
            when 40..59 then locale.t :less_than_x_minutes, count: 1
            else             locale.t :x_minutes,           count: 1
            end

          when 2...45           then locale.t :x_minutes,      count: distance_in_minutes
          when 45...90          then locale.t :about_x_hours,  count: 1
            # 90 mins up to 24 hours
          when 90...1440        then locale.t :about_x_hours,  count: (distance_in_minutes.to_f / 60.0).round
            # 24 hours up to 42 hours
          when 1440...2520      then locale.t :x_days,         count: 1
            # 42 hours up to 30 days
          when 2520...43200     then locale.t :x_days,         count: (distance_in_minutes.to_f / 1440.0).round
            # 30 days up to 60 days
          when 43200...86400    then locale.t :about_x_months, count: (distance_in_minutes.to_f / 43200.0).round
            # 60 days up to 365 days
          when 86400...525600   then locale.t :x_months,       count: (distance_in_minutes.to_f / 43200.0).round
          else
            from_year = from_time.year
            from_year += 1 if from_time.month >= 3
            to_year = to_time.year
            to_year -= 1 if to_time.month < 3
            leap_years = (from_year > to_year) ? 0 : (from_year..to_year).count { |x| Date.leap?(x) }
            minute_offset_for_leap_year = leap_years * 1440
            # Discount the leap year days when calculating year distance.
            # e.g. if there are 20 leap year days between 2 dates having the same day
            # and month then based on 365 days calculation
            # the distance in years will come out to over 80 years when in written
            # English it would read better as about 80 years.
            minutes_with_offset = distance_in_minutes - minute_offset_for_leap_year
            remainder                   = (minutes_with_offset % MINUTES_IN_YEAR)
            distance_in_years           = (minutes_with_offset.div MINUTES_IN_YEAR)
            if remainder < MINUTES_IN_QUARTER_YEAR
              locale.t(:about_x_years,  count: distance_in_years)
            elsif remainder < MINUTES_IN_THREE_QUARTERS_YEAR
              locale.t(:over_x_years,   count: distance_in_years)
            else
              locale.t(:almost_x_years, count: distance_in_years + 1)
            end
          end
        end
      end

      # Like <tt>distance_of_time_in_words</tt>, but where <tt>to_time</tt> is fixed to <tt>Time.now</tt>.
      #
      #   time_ago_in_words(3.minutes.from_now)                 # => 3 minutes
      #   time_ago_in_words(3.minutes.ago)                      # => 3 minutes
      #   time_ago_in_words(Time.now - 15.hours)                # => about 15 hours
      #   time_ago_in_words(Time.now)                           # => less than a minute
      #   time_ago_in_words(Time.now, include_seconds: true) # => less than 5 seconds
      #
      #   from_time = Time.now - 3.days - 14.minutes - 25.seconds
      #   time_ago_in_words(from_time)      # => 3 days
      #
      #   from_time = (3.days + 14.minutes + 25.seconds).ago
      #   time_ago_in_words(from_time)      # => 3 days
      #
      # Note that you cannot pass a <tt>Numeric</tt> value to <tt>time_ago_in_words</tt>.
      #
      def time_ago_in_words(from_time, options = {})
        distance_of_time_in_words(from_time, Time.now, options)
      end

      alias_method :distance_of_time_in_words_to_now, :time_ago_in_words

      # Returns a set of select tags (one for year, month, and day) pre-selected for accessing a specified date-based
      # attribute (identified by +method+) on an object assigned to the template (identified by +object+).
      #
      # ==== Options
      # * <tt>:use_month_numbers</tt> - Set to true if you want to use month numbers rather than month names (e.g.
      #   "2" instead of "February").
      # * <tt>:use_two_digit_numbers</tt> - Set to true if you want to display two digit month and day numbers (e.g.
      #   "02" instead of "February" and "08" instead of "8").
      # * <tt>:use_short_month</tt>   - Set to true if you want to use abbreviated month names instead of full
      #   month names (e.g. "Feb" instead of "February").
      # * <tt>:add_month_numbers</tt>  - Set to true if you want to use both month numbers and month names (e.g.
      #   "2 - February" instead of "February").
      # * <tt>:use_month_names</tt>   - Set to an array with 12 month names if you want to customize month names.
      #   Note: You can also use Rails' i18n functionality for this.
      # * <tt>:month_format_string</tt> - Set to a format string. The string gets passed keys +:number+ (integer)
      #   and +:name+ (string). A format string would be something like "%{name} (%<number>02d)" for example.
      #   See <tt>Kernel.sprintf</tt> for documentation on format sequences.
      # * <tt>:date_separator</tt>    - Specifies a string to separate the date fields. Default is "" (i.e. nothing).
      # * <tt>:time_separator</tt>    - Specifies a string to separate the time fields. Default is " : ".
      # * <tt>:datetime_separator</tt>- Specifies a string to separate the date and time fields. Default is " &mdash; ".
      # * <tt>:start_year</tt>        - Set the start year for the year select. Default is <tt>Date.today.year - 5</tt> if
      #   you are creating new record. While editing existing record, <tt>:start_year</tt> defaults to
      #   the current selected year minus 5.
      # * <tt>:end_year</tt>          - Set the end year for the year select. Default is <tt>Date.today.year + 5</tt> if
      #   you are creating new record. While editing existing record, <tt>:end_year</tt> defaults to
      #   the current selected year plus 5.
      # * <tt>:year_format</tt>       - Set format of years for year select. Lambda should be passed.
      # * <tt>:day_format</tt>        - Set format of days for day select. Lambda should be passed.
      # * <tt>:discard_day</tt>       - Set to true if you don't want to show a day select. This includes the day
      #   as a hidden field instead of showing a select field. Also note that this implicitly sets the day to be the
      #   first of the given month in order to not create invalid dates like 31 February.
      # * <tt>:discard_month</tt>     - Set to true if you don't want to show a month select. This includes the month
      #   as a hidden field instead of showing a select field. Also note that this implicitly sets :discard_day to true.
      # * <tt>:discard_year</tt>      - Set to true if you don't want to show a year select. This includes the year
      #   as a hidden field instead of showing a select field.
      # * <tt>:order</tt>             - Set to an array containing <tt>:day</tt>, <tt>:month</tt> and <tt>:year</tt> to
      #   customize the order in which the select fields are shown. If you leave out any of the symbols, the respective
      #   select will not be shown (like when you set <tt>discard_xxx: true</tt>. Defaults to the order defined in
      #   the respective locale (e.g. [:year, :month, :day] in the en locale that ships with \Rails).
      # * <tt>:include_blank</tt>     - Include a blank option in every select field so it's possible to set empty
      #   dates.
      # * <tt>:default</tt>           - Set a default date if the affected date isn't set or is +nil+.
      # * <tt>:selected</tt>          - Set a date that overrides the actual value.
      # * <tt>:disabled</tt>          - Set to true if you want show the select fields as disabled.
      # * <tt>:prompt</tt>            - Set to true (for a generic prompt), a prompt string or a hash of prompt strings
      #   for <tt>:year</tt>, <tt>:month</tt>, <tt>:day</tt>, <tt>:hour</tt>, <tt>:minute</tt> and <tt>:second</tt>.
      #   Setting this option prepends a select option with a generic prompt  (Day, Month, Year, Hour, Minute, Seconds)
      #   or the given prompt string.
      # * <tt>:with_css_classes</tt>  - Set to true or a hash of strings. Use true if you want to assign generic styles for
      #   select tags. This automatically set classes 'year', 'month', 'day', 'hour', 'minute' and 'second'. A hash of
      #   strings for <tt>:year</tt>, <tt>:month</tt>, <tt>:day</tt>, <tt>:hour</tt>, <tt>:minute</tt>, <tt>:second</tt>
      #   will extend the select type with the given value. Use +html_options+ to modify every select tag in the set.
      # * <tt>:use_hidden</tt>         - Set to true if you only want to generate hidden input tags.
      #
      # If anything is passed in the +html_options+ hash it will be applied to every select tag in the set.
      #
      # NOTE: Discarded selects will default to 1. So if no month select is available, January will be assumed.
      #
      #   # Generates a date select that when POSTed is stored in the article variable, in the written_on attribute.
      #   date_select("article", "written_on")
      #
      #   # Generates a date select that when POSTed is stored in the article variable, in the written_on attribute,
      #   # with the year in the year drop down box starting at 1995.
      #   date_select("article", "written_on", start_year: 1995)
      #
      #   # Generates a date select that when POSTed is stored in the article variable, in the written_on attribute,
      #   # with the year in the year drop down box starting at 1995, numbers used for months instead of words,
      #   # and without a day select box.
      #   date_select("article", "written_on", start_year: 1995, use_month_numbers: true,
      #                                     discard_day: true, include_blank: true)
      #
      #   # Generates a date select that when POSTed is stored in the article variable, in the written_on attribute,
      #   # with two digit numbers used for months and days.
      #   date_select("article", "written_on", use_two_digit_numbers: true)
      #
      #   # Generates a date select that when POSTed is stored in the article variable, in the written_on attribute
      #   # with the fields ordered as day, month, year rather than month, day, year.
      #   date_select("article", "written_on", order: [:day, :month, :year])
      #
      #   # Generates a date select that when POSTed is stored in the user variable, in the birthday attribute
      #   # lacking a year field.
      #   date_select("user", "birthday", order: [:month, :day])
      #
      #   # Generates a date select that when POSTed is stored in the article variable, in the written_on attribute
      #   # which is initially set to the date 3 days from the current date
      #   date_select("article", "written_on", default: 3.days.from_now)
      #
      #   # Generates a date select that when POSTed is stored in the article variable, in the written_on attribute
      #   # which is set in the form with today's date, regardless of the value in the Active Record object.
      #   date_select("article", "written_on", selected: Date.today)
      #
      #   # Generates a date select that when POSTed is stored in the credit_card variable, in the bill_due attribute
      #   # that will have a default day of 20.
      #   date_select("credit_card", "bill_due", default: { day: 20 })
      #
      #   # Generates a date select with custom prompts.
      #   date_select("article", "written_on", prompt: { day: 'Select day', month: 'Select month', year: 'Select year' })
      #
      #   # Generates a date select with custom year format.
      #   date_select("article", "written_on", year_format: ->(year) { "Heisei #{year - 1988}" })
      #
      #   # Generates a date select with custom day format.
      #   date_select("article", "written_on", day_format: ->(day) { day.ordinalize })
      #
      # The selects are prepared for multi-parameter assignment to an Active Record object.
      #
      # Note: If the day is not included as an option but the month is, the day will be set to the 1st to ensure that
      # all month choices are valid.
      def date_select(object_name, method, options = {}, html_options = {})
        Tags::DateSelect.new(object_name, method, self, options, html_options).render
      end

      # Returns a set of select tags (one for hour, minute, and optionally second) pre-selected for accessing a
      # specified time-based attribute (identified by +method+) on an object assigned to the template (identified by
      # +object+). You can include the seconds with <tt>:include_seconds</tt>. You can get hours in the AM/PM format
      # with <tt>:ampm</tt> option.
      #
      # This method will also generate 3 input hidden tags, for the actual year, month, and day unless the option
      # <tt>:ignore_date</tt> is set to +true+. If you set the <tt>:ignore_date</tt> to +true+, you must have a
      # +date_select+ on the same method within the form otherwise an exception will be raised.
      #
      # If anything is passed in the html_options hash it will be applied to every select tag in the set.
      #
      #   # Creates a time select tag that, when POSTed, will be stored in the article variable in the sunrise attribute.
      #   time_select("article", "sunrise")
      #
      #   # Creates a time select tag with a seconds field that, when POSTed, will be stored in the article variables in
      #   # the sunrise attribute.
      #   time_select("article", "start_time", include_seconds: true)
      #
      #   # You can set the <tt>:minute_step</tt> to 15 which will give you: 00, 15, 30, and 45.
      #   time_select 'game', 'game_time', { minute_step: 15 }
      #
      #   # Creates a time select tag with a custom prompt. Use <tt>prompt: true</tt> for generic prompts.
      #   time_select("article", "written_on", prompt: { hour: 'Choose hour', minute: 'Choose minute', second: 'Choose seconds' })
      #   time_select("article", "written_on", prompt: { hour: true }) # generic prompt for hours
      #   time_select("article", "written_on", prompt: true) # generic prompts for all
      #
      #   # You can set :ampm option to true which will show the hours as: 12 PM, 01 AM .. 11 PM.
      #   time_select 'game', 'game_time', { ampm: true }
      #
      #   # You can set :ignore_date option to true which will remove the hidden inputs for day,
      #   # month, and year that are set by default on this helper when you only want the time inputs
      #   time_select 'game', 'game_time', { ignore_date: true }
      #
      # The selects are prepared for multi-parameter assignment to an Active Record object.
      #
      # Note: If the day is not included as an option but the month is, the day will be set to the 1st to ensure that
      # all month choices are valid.
      def time_select(object_name, method, options = {}, html_options = {})
        Tags::TimeSelect.new(object_name, method, self, options, html_options).render
      end

      # Returns a set of select tags (one for year, month, day, hour, and minute) pre-selected for accessing a
      # specified datetime-based attribute (identified by +method+) on an object assigned to the template (identified
      # by +object+).
      #
      # If anything is passed in the html_options hash it will be applied to every select tag in the set.
      #
      #   # Generates a datetime select that, when POSTed, will be stored in the article variable in the written_on
      #   # attribute.
      #   datetime_select("article", "written_on")
      #
      #   # Generates a datetime select with a year select that starts at 1995 that, when POSTed, will be stored in the
      #   # article variable in the written_on attribute.
      #   datetime_select("article", "written_on", start_year: 1995)
      #
      #   # Generates a datetime select with a default value of 3 days from the current time that, when POSTed, will
      #   # be stored in the trip variable in the departing attribute.
      #   datetime_select("trip", "departing", default: 3.days.from_now)
      #
      #   # Generate a datetime select with hours in the AM/PM format
      #   datetime_select("article", "written_on", ampm: true)
      #
      #   # Generates a datetime select that discards the type that, when POSTed, will be stored in the article variable
      #   # as the written_on attribute.
      #   datetime_select("article", "written_on", discard_type: true)
      #
      #   # Generates a datetime select with a custom prompt. Use <tt>prompt: true</tt> for generic prompts.
      #   datetime_select("article", "written_on", prompt: { day: 'Choose day', month: 'Choose month', year: 'Choose year' })
      #   datetime_select("article", "written_on", prompt: { hour: true }) # generic prompt for hours
      #   datetime_select("article", "written_on", prompt: true) # generic prompts for all
      #
      # The selects are prepared for multi-parameter assignment to an Active Record object.
      def datetime_select(object_name, method, options = {}, html_options = {})
        Tags::DatetimeSelect.new(object_name, method, self, options, html_options).render
      end

      # Returns a set of HTML select-tags (one for year, month, day, hour, minute, and second) pre-selected with the
      # +datetime+. It's also possible to explicitly set the order of the tags using the <tt>:order</tt> option with
      # an array of symbols <tt>:year</tt>, <tt>:month</tt> and <tt>:day</tt> in the desired order. If you do not
      # supply a Symbol, it will be appended onto the <tt>:order</tt> passed in. You can also add
      # <tt>:date_separator</tt>, <tt>:datetime_separator</tt> and <tt>:time_separator</tt> keys to the +options+ to
      # control visual display of the elements.
      #
      # If anything is passed in the html_options hash it will be applied to every select tag in the set.
      #
      #   my_date_time = Time.now + 4.days
      #
      #   # Generates a datetime select that defaults to the datetime in my_date_time (four days after today).
      #   select_datetime(my_date_time)
      #
      #   # Generates a datetime select that defaults to today (no specified datetime)
      #   select_datetime()
      #
      #   # Generates a datetime select that defaults to the datetime in my_date_time (four days after today)
      #   # with the fields ordered year, month, day rather than month, day, year.
      #   select_datetime(my_date_time, order: [:year, :month, :day])
      #
      #   # Generates a datetime select that defaults to the datetime in my_date_time (four days after today)
      #   # with a '/' between each date field.
      #   select_datetime(my_date_time, date_separator: '/')
      #
      #   # Generates a datetime select that defaults to the datetime in my_date_time (four days after today)
      #   # with a date fields separated by '/', time fields separated by '' and the date and time fields
      #   # separated by a comma (',').
      #   select_datetime(my_date_time, date_separator: '/', time_separator: '', datetime_separator: ',')
      #
      #   # Generates a datetime select that discards the type of the field and defaults to the datetime in
      #   # my_date_time (four days after today)
      #   select_datetime(my_date_time, discard_type: true)
      #
      #   # Generate a datetime field with hours in the AM/PM format
      #   select_datetime(my_date_time, ampm: true)
      #
      #   # Generates a datetime select that defaults to the datetime in my_date_time (four days after today)
      #   # prefixed with 'payday' rather than 'date'
      #   select_datetime(my_date_time, prefix: 'payday')
      #
      #   # Generates a datetime select with a custom prompt. Use <tt>prompt: true</tt> for generic prompts.
      #   select_datetime(my_date_time, prompt: { day: 'Choose day', month: 'Choose month', year: 'Choose year' })
      #   select_datetime(my_date_time, prompt: { hour: true }) # generic prompt for hours
      #   select_datetime(my_date_time, prompt: true) # generic prompts for all
      def select_datetime(datetime = Time.current, options = {}, html_options = {})
        DateTimeSelector.new(datetime, options, html_options).select_datetime
      end

      # Returns a set of HTML select-tags (one for year, month, and day) pre-selected with the +date+.
      # It's possible to explicitly set the order of the tags using the <tt>:order</tt> option with an array of
      # symbols <tt>:year</tt>, <tt>:month</tt> and <tt>:day</tt> in the desired order.
      # If the array passed to the <tt>:order</tt> option does not contain all the three symbols, all tags will be hidden.
      #
      # If anything is passed in the html_options hash it will be applied to every select tag in the set.
      #
      #   my_date = Time.now + 6.days
      #
      #   # Generates a date select that defaults to the date in my_date (six days after today).
      #   select_date(my_date)
      #
      #   # Generates a date select that defaults to today (no specified date).
      #   select_date()
      #
      #   # Generates a date select that defaults to the date in my_date (six days after today)
      #   # with the fields ordered year, month, day rather than month, day, year.
      #   select_date(my_date, order: [:year, :month, :day])
      #
      #   # Generates a date select that discards the type of the field and defaults to the date in
      #   # my_date (six days after today).
      #   select_date(my_date, discard_type: true)
      #
      #   # Generates a date select that defaults to the date in my_date,
      #   # which has fields separated by '/'.
      #   select_date(my_date, date_separator: '/')
      #
      #   # Generates a date select that defaults to the datetime in my_date (six days after today)
      #   # prefixed with 'payday' rather than 'date'.
      #   select_date(my_date, prefix: 'payday')
      #
      #   # Generates a date select with a custom prompt. Use <tt>prompt: true</tt> for generic prompts.
      #   select_date(my_date, prompt: { day: 'Choose day', month: 'Choose month', year: 'Choose year' })
      #   select_date(my_date, prompt: { hour: true }) # generic prompt for hours
      #   select_date(my_date, prompt: true) # generic prompts for all
      def select_date(date = Date.current, options = {}, html_options = {})
        DateTimeSelector.new(date, options, html_options).select_date
      end

      # Returns a set of HTML select-tags (one for hour and minute).
      # You can set <tt>:time_separator</tt> key to format the output, and
      # the <tt>:include_seconds</tt> option to include an input for seconds.
      #
      # If anything is passed in the html_options hash it will be applied to every select tag in the set.
      #
      #   my_time = Time.now + 5.days + 7.hours + 3.minutes + 14.seconds
      #
      #   # Generates a time select that defaults to the time in my_time.
      #   select_time(my_time)
      #
      #   # Generates a time select that defaults to the current time (no specified time).
      #   select_time()
      #
      #   # Generates a time select that defaults to the time in my_time,
      #   # which has fields separated by ':'.
      #   select_time(my_time, time_separator: ':')
      #
      #   # Generates a time select that defaults to the time in my_time,
      #   # that also includes an input for seconds.
      #   select_time(my_time, include_seconds: true)
      #
      #   # Generates a time select that defaults to the time in my_time, that has fields
      #   # separated by ':' and includes an input for seconds.
      #   select_time(my_time, time_separator: ':', include_seconds: true)
      #
      #   # Generate a time select field with hours in the AM/PM format
      #   select_time(my_time, ampm: true)
      #
      #   # Generates a time select field with hours that range from 2 to 14
      #   select_time(my_time, start_hour: 2, end_hour: 14)
      #
      #   # Generates a time select with a custom prompt. Use <tt>:prompt</tt> to true for generic prompts.
      #   select_time(my_time, prompt: { day: 'Choose day', month: 'Choose month', year: 'Choose year' })
      #   select_time(my_time, prompt: { hour: true }) # generic prompt for hours
      #   select_time(my_time, prompt: true) # generic prompts for all
      def select_time(datetime = Time.current, options = {}, html_options = {})
        DateTimeSelector.new(datetime, options, html_options).select_time
      end

      # Returns a select tag with options for each of the seconds 0 through 59 with the current second selected.
      # The <tt>datetime</tt> can be either a +Time+ or +DateTime+ object or an integer.
      # Override the field name using the <tt>:field_name</tt> option, 'second' by default.
      #
      #   my_time = Time.now + 16.seconds
      #
      #   # Generates a select field for seconds that defaults to the seconds for the time in my_time.
      #   select_second(my_time)
      #
      #   # Generates a select field for seconds that defaults to the number given.
      #   select_second(33)
      #
      #   # Generates a select field for seconds that defaults to the seconds for the time in my_time
      #   # that is named 'interval' rather than 'second'.
      #   select_second(my_time, field_name: 'interval')
      #
      #   # Generates a select field for seconds with a custom prompt. Use <tt>prompt: true</tt> for a
      #   # generic prompt.
      #   select_second(14, prompt: 'Choose seconds')
      def select_second(datetime, options = {}, html_options = {})
        DateTimeSelector.new(datetime, options, html_options).select_second
      end

      # Returns a select tag with options for each of the minutes 0 through 59 with the current minute selected.
      # Also can return a select tag with options by <tt>minute_step</tt> from 0 through 59 with the 00 minute
      # selected. The <tt>datetime</tt> can be either a +Time+ or +DateTime+ object or an integer.
      # Override the field name using the <tt>:field_name</tt> option, 'minute' by default.
      #
      #   my_time = Time.now + 10.minutes
      #
      #   # Generates a select field for minutes that defaults to the minutes for the time in my_time.
      #   select_minute(my_time)
      #
      #   # Generates a select field for minutes that defaults to the number given.
      #   select_minute(14)
      #
      #   # Generates a select field for minutes that defaults to the minutes for the time in my_time
      #   # that is named 'moment' rather than 'minute'.
      #   select_minute(my_time, field_name: 'moment')
      #
      #   # Generates a select field for minutes with a custom prompt. Use <tt>prompt: true</tt> for a
      #   # generic prompt.
      #   select_minute(14, prompt: 'Choose minutes')
      def select_minute(datetime, options = {}, html_options = {})
        DateTimeSelector.new(datetime, options, html_options).select_minute
      end

      # Returns a select tag with options for each of the hours 0 through 23 with the current hour selected.
      # The <tt>datetime</tt> can be either a +Time+ or +DateTime+ object or an integer.
      # Override the field name using the <tt>:field_name</tt> option, 'hour' by default.
      #
      #   my_time = Time.now + 6.hours
      #
      #   # Generates a select field for hours that defaults to the hour for the time in my_time.
      #   select_hour(my_time)
      #
      #   # Generates a select field for hours that defaults to the number given.
      #   select_hour(13)
      #
      #   # Generates a select field for hours that defaults to the hour for the time in my_time
      #   # that is named 'stride' rather than 'hour'.
      #   select_hour(my_time, field_name: 'stride')
      #
      #   # Generates a select field for hours with a custom prompt. Use <tt>prompt: true</tt> for a
      #   # generic prompt.
      #   select_hour(13, prompt: 'Choose hour')
      #
      #   # Generate a select field for hours in the AM/PM format
      #   select_hour(my_time, ampm: true)
      #
      #   # Generates a select field that includes options for hours from 2 to 14.
      #   select_hour(my_time, start_hour: 2, end_hour: 14)
      def select_hour(datetime, options = {}, html_options = {})
        DateTimeSelector.new(datetime, options, html_options).select_hour
      end

      # Returns a select tag with options for each of the days 1 through 31 with the current day selected.
      # The <tt>date</tt> can also be substituted for a day number.
      # If you want to display days with a leading zero set the <tt>:use_two_digit_numbers</tt> key in +options+ to true.
      # Override the field name using the <tt>:field_name</tt> option, 'day' by default.
      #
      #   my_date = Time.now + 2.days
      #
      #   # Generates a select field for days that defaults to the day for the date in my_date.
      #   select_day(my_date)
      #
      #   # Generates a select field for days that defaults to the number given.
      #   select_day(5)
      #
      #   # Generates a select field for days that defaults to the number given, but displays it with two digits.
      #   select_day(5, use_two_digit_numbers: true)
      #
      #   # Generates a select field for days that defaults to the day for the date in my_date
      #   # that is named 'due' rather than 'day'.
      #   select_day(my_date, field_name: 'due')
      #
      #   # Generates a select field for days with a custom prompt. Use <tt>prompt: true</tt> for a
      #   # generic prompt.
      #   select_day(5, prompt: 'Choose day')
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
      # If you want to display months with a leading zero set the <tt>:use_two_digit_numbers</tt> key in +options+ to true.
      # Override the field name using the <tt>:field_name</tt> option, 'month' by default.
      #
      #   # Generates a select field for months that defaults to the current month that
      #   # will use keys like "January", "March".
      #   select_month(Date.today)
      #
      #   # Generates a select field for months that defaults to the current month that
      #   # is named "start" rather than "month".
      #   select_month(Date.today, field_name: 'start')
      #
      #   # Generates a select field for months that defaults to the current month that
      #   # will use keys like "1", "3".
      #   select_month(Date.today, use_month_numbers: true)
      #
      #   # Generates a select field for months that defaults to the current month that
      #   # will use keys like "1 - January", "3 - March".
      #   select_month(Date.today, add_month_numbers: true)
      #
      #   # Generates a select field for months that defaults to the current month that
      #   # will use keys like "Jan", "Mar".
      #   select_month(Date.today, use_short_month: true)
      #
      #   # Generates a select field for months that defaults to the current month that
      #   # will use keys like "Januar", "Marts."
      #   select_month(Date.today, use_month_names: %w(Januar Februar Marts ...))
      #
      #   # Generates a select field for months that defaults to the current month that
      #   # will use keys with two digit numbers like "01", "03".
      #   select_month(Date.today, use_two_digit_numbers: true)
      #
      #   # Generates a select field for months with a custom prompt. Use <tt>prompt: true</tt> for a
      #   # generic prompt.
      #   select_month(14, prompt: 'Choose month')
      def select_month(date, options = {}, html_options = {})
        DateTimeSelector.new(date, options, html_options).select_month
      end

      # Returns a select tag with options for each of the five years on each side of the current, which is selected.
      # The five year radius can be changed using the <tt>:start_year</tt> and <tt>:end_year</tt> keys in the
      # +options+. Both ascending and descending year lists are supported by making <tt>:start_year</tt> less than or
      # greater than <tt>:end_year</tt>. The <tt>date</tt> can also be substituted for a year given as a number.
      # Override the field name using the <tt>:field_name</tt> option, 'year' by default.
      #
      #   # Generates a select field for years that defaults to the current year that
      #   # has ascending year values.
      #   select_year(Date.today, start_year: 1992, end_year: 2007)
      #
      #   # Generates a select field for years that defaults to the current year that
      #   # is named 'birth' rather than 'year'.
      #   select_year(Date.today, field_name: 'birth')
      #
      #   # Generates a select field for years that defaults to the current year that
      #   # has descending year values.
      #   select_year(Date.today, start_year: 2005, end_year: 1900)
      #
      #   # Generates a select field for years that defaults to the year 2006 that
      #   # has ascending year values.
      #   select_year(2006, start_year: 2000, end_year: 2010)
      #
      #   # Generates a select field for years with a custom prompt. Use <tt>prompt: true</tt> for a
      #   # generic prompt.
      #   select_year(14, prompt: 'Choose year')
      def select_year(date, options = {}, html_options = {})
        DateTimeSelector.new(date, options, html_options).select_year
      end

      # Returns an HTML time tag for the given date or time.
      #
      #   time_tag Date.today  # =>
      #     <time datetime="2010-11-04">November 04, 2010</time>
      #   time_tag Time.now  # =>
      #     <time datetime="2010-11-04T17:55:45+01:00">November 04, 2010 17:55</time>
      #   time_tag Date.yesterday, 'Yesterday'  # =>
      #     <time datetime="2010-11-03">Yesterday</time>
      #   time_tag Date.today, datetime: Date.today.strftime('%G-W%V') # =>
      #     <time datetime="2010-W44">November 04, 2010</time>
      #
      #   <%= time_tag Time.now do %>
      #     <span>Right now</span>
      #   <% end %>
      #   # => <time datetime="2010-11-04T17:55:45+01:00"><span>Right now</span></time>
      def time_tag(date_or_time, *args, &block)
        options  = args.extract_options!
        format   = options.delete(:format) || :long
        content  = args.first || I18n.l(date_or_time, format: format)

        content_tag("time", content, options.reverse_merge(datetime: date_or_time.iso8601), &block)
      end

      private
        def normalize_distance_of_time_argument_to_time(value)
          if value.is_a?(Numeric)
            Time.at(value)
          elsif value.respond_to?(:to_time)
            value.to_time
          else
            raise ArgumentError, "#{value.inspect} can't be converted to a Time value"
          end
        end
    end

    class DateTimeSelector # :nodoc:
      include ActionView::Helpers::TagHelper

      DEFAULT_PREFIX = "date"
      POSITION = {
        year: 1, month: 2, day: 3, hour: 4, minute: 5, second: 6
      }.freeze

      AMPM_TRANSLATION = Hash[
        [[0, "12 AM"], [1, "01 AM"], [2, "02 AM"], [3, "03 AM"],
         [4, "04 AM"], [5, "05 AM"], [6, "06 AM"], [7, "07 AM"],
         [8, "08 AM"], [9, "09 AM"], [10, "10 AM"], [11, "11 AM"],
         [12, "12 PM"], [13, "01 PM"], [14, "02 PM"], [15, "03 PM"],
         [16, "04 PM"], [17, "05 PM"], [18, "06 PM"], [19, "07 PM"],
         [20, "08 PM"], [21, "09 PM"], [22, "10 PM"], [23, "11 PM"]]
      ].freeze

      def initialize(datetime, options = {}, html_options = {})
        @options      = options.dup
        @html_options = html_options.dup
        @datetime     = datetime
        @options[:datetime_separator] ||= " &mdash; "
        @options[:time_separator]     ||= " : "
      end

      def select_datetime
        order = date_order.dup
        order -= [:hour, :minute, :second]
        @options[:discard_year]   ||= true unless order.include?(:year)
        @options[:discard_month]  ||= true unless order.include?(:month)
        @options[:discard_day]    ||= true if @options[:discard_month] || !order.include?(:day)
        @options[:discard_minute] ||= true if @options[:discard_hour]
        @options[:discard_second] ||= true unless @options[:include_seconds] && !@options[:discard_minute]

        set_day_if_discarded

        if @options[:tag] && @options[:ignore_date]
          select_time
        else
          [:day, :month, :year].each { |o| order.unshift(o) unless order.include?(o) }
          order += [:hour, :minute, :second] unless @options[:discard_hour]

          build_selects_from_types(order)
        end
      end

      def select_date
        order = date_order.dup

        @options[:discard_hour]     = true
        @options[:discard_minute]   = true
        @options[:discard_second]   = true

        @options[:discard_year]   ||= true unless order.include?(:year)
        @options[:discard_month]  ||= true unless order.include?(:month)
        @options[:discard_day]    ||= true if @options[:discard_month] || !order.include?(:day)

        set_day_if_discarded

        [:day, :month, :year].each { |o| order.unshift(o) unless order.include?(o) }

        build_selects_from_types(order)
      end

      def select_time
        order = []

        @options[:discard_month]    = true
        @options[:discard_year]     = true
        @options[:discard_day]      = true
        @options[:discard_second] ||= true unless @options[:include_seconds]

        order += [:year, :month, :day] unless @options[:ignore_date]

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
          build_options_and_select(:minute, min, step: @options[:minute_step])
        end
      end

      def select_hour
        if @options[:use_hidden] || @options[:discard_hour]
          build_hidden(:hour, hour)
        else
          options         = {}
          options[:ampm]  = @options[:ampm] || false
          options[:start] = @options[:start_hour] || 0
          options[:end]   = @options[:end_hour] || 23
          build_options_and_select(:hour, hour, options)
        end
      end

      def select_day
        if @options[:use_hidden] || @options[:discard_day]
          build_hidden(:day, day || 1)
        else
          build_select(:day, build_day_options(day))
        end
      end

      def select_month
        if @options[:use_hidden] || @options[:discard_month]
          build_hidden(:month, month || 1)
        else
          month_options = []
          1.upto(12) do |month_number|
            options = { value: month_number }
            options[:selected] = "selected" if month == month_number
            month_options << content_tag("option", month_name(month_number), options) + "\n"
          end
          build_select(:month, month_options.join)
        end
      end

      def select_year
        if !year || @datetime == 0
          val = "1"
          middle_year = Date.today.year
        else
          val = middle_year = year
        end

        if @options[:use_hidden] || @options[:discard_year]
          build_hidden(:year, val)
        else
          options         = {}
          options[:start] = @options[:start_year] || middle_year - 5
          options[:end]   = @options[:end_year] || middle_year + 5
          options[:step]  = options[:start] < options[:end] ? 1 : -1

          max_years_allowed = @options[:max_years_allowed] || 1000

          if (options[:end] - options[:start]).abs > max_years_allowed
            raise ArgumentError, "There are too many years options to be built. Are you sure you haven't mistyped something? You can provide the :max_years_allowed parameter."
          end

          build_select(:year, build_year_options(val, options))
        end
      end

      private
        %w( sec min hour day month year ).each do |method|
          define_method(method) do
            case @datetime
            when Hash then @datetime[method.to_sym]
            when Numeric then @datetime
            when nil then nil
            else @datetime.send(method)
            end
          end
        end

        def prompt_text(prompt, type)
          prompt.kind_of?(String) ? prompt : I18n.translate(:"datetime.prompts.#{type}", locale: @options[:locale])
        end

        # If the day is hidden, the day should be set to the 1st so all month and year choices are
        # valid. Otherwise, February 31st or February 29th, 2011 can be selected, which are invalid.
        def set_day_if_discarded
          if @datetime && @options[:discard_day]
            @datetime = @datetime.change(day: 1)
          end
        end

        # Returns translated month names, but also ensures that a custom month
        # name array has a leading +nil+ element.
        def month_names
          @month_names ||= begin
            month_names = @options[:use_month_names] || translated_month_names
            month_names = [nil, *month_names] if month_names.size < 13
            month_names
          end
        end

        # Returns translated month names.
        #  => [nil, "January", "February", "March",
        #           "April", "May", "June", "July",
        #           "August", "September", "October",
        #           "November", "December"]
        #
        # If <tt>:use_short_month</tt> option is set
        #  => [nil, "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        #           "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        def translated_month_names
          key = @options[:use_short_month] ? :'date.abbr_month_names' : :'date.month_names'
          I18n.translate(key, locale: @options[:locale])
        end

        # Looks up day names by number.
        #
        #   day_name(1) # => 1
        #
        # If the <tt>use_two_digit_numbers: true</tt> option is passed to DateTimeSelector:
        #
        #   day_name(1) # => "01"
        #
        # If the <tt>day_format: ->(day) { day.ordinalize }</tt> option is passed to DateTimeSelector:
        #
        #   day_name(1) # => "1st"
        def day_name(number)
          if day_format_lambda = @options[:day_format]
            day_format_lambda.call(number)
          elsif @options[:use_two_digit_numbers]
            "%02d" % number
          else
            number
          end
        end

        # Looks up month names by number (1-based):
        #
        #   month_name(1) # => "January"
        #
        # If the <tt>:use_month_numbers</tt> option is passed:
        #
        #   month_name(1) # => 1
        #
        # If the <tt>:use_two_digit_numbers</tt> option is passed:
        #
        #   month_name(1) # => '01'
        #
        # If the <tt>:add_month_numbers</tt> option is passed:
        #
        #   month_name(1) # => "1 - January"
        #
        # If the <tt>:month_format_string</tt> option is passed:
        #
        #   month_name(1) # => "January (01)"
        #
        # depending on the format string.
        def month_name(number)
          if @options[:use_month_numbers]
            number
          elsif @options[:use_two_digit_numbers]
            "%02d" % number
          elsif @options[:add_month_numbers]
            "#{number} - #{month_names[number]}"
          elsif format_string = @options[:month_format_string]
            format_string % { number: number, name: month_names[number] }
          else
            month_names[number]
          end
        end

        # Looks up year names by number.
        #
        #   year_name(1998) # => 1998
        #
        # If the <tt>:year_format</tt> option is passed:
        #
        #   year_name(1998) # => "Heisei 10"
        def year_name(number)
          if year_format_lambda = @options[:year_format]
            year_format_lambda.call(number)
          else
            number
          end
        end

        def date_order
          @date_order ||= @options[:order] || translated_date_order
        end

        def translated_date_order
          date_order = I18n.translate(:'date.order', locale: @options[:locale], default: [])
          date_order = date_order.map(&:to_sym)

          forbidden_elements = date_order - [:year, :month, :day]
          if forbidden_elements.any?
            raise StandardError,
              "#{@options[:locale]}.date.order only accepts :year, :month and :day"
          end

          date_order
        end

        # Build full select tag from date type and options.
        def build_options_and_select(type, selected, options = {})
          build_select(type, build_options(selected, options))
        end

        # Build select option HTML from date value and options.
        #
        #   build_options(15, start: 1, end: 31)
        #   => "<option value="1">1</option>
        #       <option value="2">2</option>
        #       <option value="3">3</option>..."
        #
        # If <tt>use_two_digit_numbers: true</tt> option is passed:
        #
        #   build_options(15, start: 1, end: 31, use_two_digit_numbers: true)
        #   => "<option value="1">01</option>
        #       <option value="2">02</option>
        #       <option value="3">03</option>..."
        #
        # If <tt>:step</tt> options is passed:
        #
        #   build_options(15, start: 1, end: 31, step: 2)
        #   => "<option value="1">1</option>
        #       <option value="3">3</option>
        #       <option value="5">5</option>..."
        def build_options(selected, options = {})
          options = {
            leading_zeros: true, ampm: false, use_two_digit_numbers: false
          }.merge!(options)

          start         = options.delete(:start) || 0
          stop          = options.delete(:end) || 59
          step          = options.delete(:step) || 1
          leading_zeros = options.delete(:leading_zeros)

          select_options = []
          start.step(stop, step) do |i|
            value = leading_zeros ? sprintf("%02d", i) : i
            tag_options = { value: value }
            tag_options[:selected] = "selected" if selected == i
            text = options[:use_two_digit_numbers] ? sprintf("%02d", i) : value
            text = options[:ampm] ? AMPM_TRANSLATION[i] : text
            select_options << content_tag("option", text, tag_options)
          end

          (select_options.join("\n") + "\n").html_safe
        end

        # Build select option HTML for day.
        #
        #   build_day_options(2)
        #   => "<option value="1">1</option>
        #       <option value="2" selected="selected">2</option>
        #       <option value="3">3</option>..."
        #
        # If <tt>day_format: ->(day) { day.ordinalize }</tt> option is passed to DateTimeSelector
        #
        #   build_day_options(2)
        #   => "<option value="1">1st</option>
        #       <option value="2" selected="selected">2nd</option>
        #       <option value="3">3rd</option>..."
        #
        # If <tt>use_two_digit_numbers: true</tt> option is passed to DateTimeSelector
        #
        #   build_day_options(2)
        #   => "<option value="1">01</option>
        #       <option value="2" selected="selected">02</option>
        #       <option value="3">03</option>..."
        def build_day_options(selected)
          select_options = []
          (1..31).each do |value|
            tag_options = { value: value }
            tag_options[:selected] = "selected" if selected == value
            text = day_name(value)
            select_options << content_tag("option", text, tag_options)
          end

          (select_options.join("\n") + "\n").html_safe
        end

        # Build select option HTML for year.
        #
        #   build_year_options(1998, start: 1998, end: 2000)
        #   => "<option value="1998" selected="selected">1998</option>
        #       <option value="1999">1999</option>
        #       <option value="2000">2000</option>"
        def build_year_options(selected, options = {})
          start = options.delete(:start)
          stop = options.delete(:end)
          step = options.delete(:step)

          select_options = []
          start.step(stop, step) do |value|
            tag_options = { value: value }
            tag_options[:selected] = "selected" if selected == value
            text = year_name(value)
            select_options << content_tag("option", text, tag_options)
          end

          (select_options.join("\n") + "\n").html_safe
        end

        # Builds select tag from date type and HTML select options.
        #
        #   build_select(:month, "<option value="1">January</option>...")
        #   => "<select id="post_written_on_2i" name="post[written_on(2i)]">
        #         <option value="1">January</option>...
        #       </select>"
        def build_select(type, select_options_as_html)
          select_options = {
            id: input_id_from_type(type),
            name: input_name_from_type(type)
          }.merge!(@html_options)
          select_options[:disabled] = "disabled" if @options[:disabled]
          select_options[:class] = css_class_attribute(type, select_options[:class], @options[:with_css_classes]) if @options[:with_css_classes]

          select_html = +"\n"
          select_html << content_tag("option", "", value: "", label: " ") + "\n" if @options[:include_blank]
          select_html << prompt_option_tag(type, @options[:prompt]) + "\n" if @options[:prompt]
          select_html << select_options_as_html

          (content_tag("select", select_html.html_safe, select_options) + "\n").html_safe
        end

        # Builds the CSS class value for the select element.
        #
        #   css_class_attribute(:year, 'date optional', { year: 'my-year' })
        #   => "date optional my-year"
        def css_class_attribute(type, html_options_class, options) # :nodoc:
          css_class = \
            case options
            when Hash
              options[type.to_sym]
            else
              type
            end

          [html_options_class, css_class].compact.join(" ")
        end

        # Builds a prompt option tag with supplied options or from default options.
        #
        #   prompt_option_tag(:month, prompt: 'Select month')
        #   => "<option value="">Select month</option>"
        def prompt_option_tag(type, options)
          prompt = \
            case options
            when Hash
              default_options = { year: false, month: false, day: false, hour: false, minute: false, second: false }
              default_options.merge!(options)[type.to_sym]
            when String
              options
            else
              I18n.translate(:"datetime.prompts.#{type}", locale: @options[:locale])
            end

          prompt ? content_tag("option", prompt_text(prompt, type), value: "") : ""
        end

        # Builds hidden input tag for date part and value.
        #
        #   build_hidden(:year, 2008)
        #   => "<input type="hidden" id="date_year" name="date[year]" value="2008" autocomplete="off" />"
        def build_hidden(type, value)
          select_options = {
            type: "hidden",
            id: input_id_from_type(type),
            name: input_name_from_type(type),
            value: value,
            autocomplete: "off"
          }.merge!(@html_options.slice(:disabled))
          select_options[:disabled] = "disabled" if @options[:disabled]

          tag(:input, select_options) + "\n".html_safe
        end

        # Returns the name attribute for the input tag.
        #  => post[written_on(1i)]
        def input_name_from_type(type)
          prefix = @options[:prefix] || ActionView::Helpers::DateTimeSelector::DEFAULT_PREFIX
          prefix += "[#{@options[:index]}]" if @options.has_key?(:index)

          field_name = @options[:field_name] || type.to_s
          if @options[:include_position]
            field_name += "(#{ActionView::Helpers::DateTimeSelector::POSITION[type]}i)"
          end

          @options[:discard_type] ? prefix : "#{prefix}[#{field_name}]"
        end

        # Returns the id attribute for the input tag.
        #  => "post_written_on_1i"
        def input_id_from_type(type)
          id = input_name_from_type(type).gsub(/([\[(])|(\]\[)/, "_").gsub(/[\])]/, "")
          id = @options[:namespace] + "_" + id if @options[:namespace]

          id
        end

        # Given an ordering of datetime components, create the selection HTML
        # and join them with their appropriate separators.
        def build_selects_from_types(order)
          select = +""
          first_visible = order.find { |type| !@options[:"discard_#{type}"] }
          order.reverse_each do |type|
            separator = separator(type) unless type == first_visible # don't add before first visible field
            select.insert(0, separator.to_s + public_send("select_#{type}").to_s)
          end
          select.html_safe
        end

        # Returns the separator for a given datetime component.
        def separator(type)
          return "" if @options[:use_hidden]

          case type
          when :year, :month, :day
            @options[:"discard_#{type}"] ? "" : @options[:date_separator]
          when :hour
            (@options[:discard_year] && @options[:discard_day]) ? "" : @options[:datetime_separator]
          when :minute, :second
            @options[:"discard_#{type}"] ? "" : @options[:time_separator]
          end
        end
    end

    class FormBuilder
      # Wraps ActionView::Helpers::DateHelper#date_select for form builders:
      #
      #   <%= form_with model: @person do |f| %>
      #     <%= f.date_select :birth_date %>
      #     <%= f.submit %>
      #   <% end %>
      #
      # Please refer to the documentation of the base helper for details.
      def date_select(method, options = {}, html_options = {})
        @template.date_select(@object_name, method, objectify_options(options), html_options)
      end

      # Wraps ActionView::Helpers::DateHelper#time_select for form builders:
      #
      #   <%= form_with model: @race do |f| %>
      #     <%= f.time_select :average_lap %>
      #     <%= f.submit %>
      #   <% end %>
      #
      # Please refer to the documentation of the base helper for details.
      def time_select(method, options = {}, html_options = {})
        @template.time_select(@object_name, method, objectify_options(options), html_options)
      end

      # Wraps ActionView::Helpers::DateHelper#datetime_select for form builders:
      #
      #   <%= form_with model: @person do |f| %>
      #     <%= f.datetime_select :last_request_at %>
      #     <%= f.submit %>
      #   <% end %>
      #
      # Please refer to the documentation of the base helper for details.
      def datetime_select(method, options = {}, html_options = {})
        @template.datetime_select(@object_name, method, objectify_options(options), html_options)
      end
    end
  end
end
