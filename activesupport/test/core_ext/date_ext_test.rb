# frozen_string_literal: true

require_relative "../abstract_unit"
require "active_support/time"
require_relative "../core_ext/date_and_time_behavior"
require_relative "../time_zone_test_helpers"

class DateExtCalculationsTest < ActiveSupport::TestCase
  def date_time_init(year, month, day, *args)
    Date.new(year, month, day)
  end

  include DateAndTimeBehavior
  include TimeZoneTestHelpers

  def test_yesterday_in_calendar_reform
    assert_equal Date.new(1582, 10, 4), Date.new(1582, 10, 15).yesterday
  end

  def test_tomorrow_in_calendar_reform
    assert_equal Date.new(1582, 10, 15), Date.new(1582, 10, 4).tomorrow
  end

  def test_to_fs
    date = Date.new(2005, 2, 21)
    assert_equal "21 Feb",              date.to_fs(:short)
    assert_equal "February 21, 2005",   date.to_fs(:long)
    assert_equal "February 21st, 2005", date.to_fs(:long_ordinal)
    assert_equal "2005-02-21",          date.to_fs(:db)
    assert_equal "2005-02-21",          date.to_fs(:inspect)
    assert_equal "21 Feb 2005",         date.to_fs(:rfc822)
    assert_equal "21 Feb 2005",         date.to_fs(:rfc2822)
    assert_equal "2005-02-21",          date.to_fs(:iso8601)
    assert_equal date.to_s,             date.to_fs(:doesnt_exist)
    assert_equal "21 Feb",              date.to_formatted_s(:short)
  end

  def test_to_fs_with_single_digit_day
    date = Date.new(2005, 2, 1)
    assert_equal "01 Feb",              date.to_fs(:short)
    assert_equal "February 01, 2005",   date.to_fs(:long)
    assert_equal "February 1st, 2005",  date.to_fs(:long_ordinal)
    assert_equal "2005-02-01",          date.to_fs(:db)
    assert_equal "2005-02-01",          date.to_fs(:inspect)
    assert_equal "01 Feb 2005",         date.to_fs(:rfc822)
    assert_equal "2005-02-01",          date.to_fs(:iso8601)
  end

  def test_readable_inspect
    assert_equal "Mon, 21 Feb 2005", Date.new(2005, 2, 21).readable_inspect
    assert_equal Date.new(2005, 2, 21).readable_inspect, Date.new(2005, 2, 21).inspect
  end

  def test_to_time
    with_env_tz "US/Eastern" do
      assert_equal Time, Date.new(2005, 2, 21).to_time.class
      assert_equal Time.local(2005, 2, 21), Date.new(2005, 2, 21).to_time
      assert_equal Time.local(2005, 2, 21).utc_offset, Date.new(2005, 2, 21).to_time.utc_offset
    end

    silence_warnings do
      0.upto(138) do |year|
        [:utc, :local].each do |format|
          assert_equal year, Date.new(year).to_time(format).year
        end
      end
    end

    assert_raise(ArgumentError) do
      Date.new(2005, 2, 21).to_time(:tokyo)
    end
  end

  def test_compare_to_time
    assert Date.yesterday < Time.now
  end

  def test_to_datetime
    assert_equal DateTime.civil(2005, 2, 21), Date.new(2005, 2, 21).to_datetime
    assert_equal 0, Date.new(2005, 2, 21).to_datetime.offset # use UTC offset
    assert_equal ::Date::ITALY, Date.new(2005, 2, 21).to_datetime.start # use Ruby's default start value
  end

  def test_to_date
    assert_equal Date.new(2005, 2, 21), Date.new(2005, 2, 21).to_date
  end

  def test_change
    assert_equal Date.new(2005, 2, 21), Date.new(2005, 2, 11).change(day: 21)
    assert_equal Date.new(2007, 5, 11), Date.new(2005, 2, 11).change(year: 2007, month: 5)
    assert_equal Date.new(2006, 2, 22), Date.new(2005, 2, 22).change(year: 2006)
    assert_equal Date.new(2005, 6, 22), Date.new(2005, 2, 22).change(month: 6)
  end

  def test_sunday
    assert_equal Date.new(2008, 3, 2), Date.new(2008, 3, 02).sunday
    assert_equal Date.new(2008, 3, 2), Date.new(2008, 2, 29).sunday
  end

  def test_beginning_of_week_in_calendar_reform
    assert_equal Date.new(1582, 10, 1), Date.new(1582, 10, 15).beginning_of_week # friday
  end

  def test_end_of_week_in_calendar_reform
    assert_equal Date.new(1582, 10, 17), Date.new(1582, 10, 4).end_of_week # thursday
  end

  def test_end_of_year
    assert_equal Date.new(2008, 12, 31).to_s, Date.new(2008, 2, 22).end_of_year.to_s
  end

  def test_end_of_month
    assert_equal Date.new(2005, 3, 31), Date.new(2005, 3, 20).end_of_month
    assert_equal Date.new(2005, 2, 28), Date.new(2005, 2, 20).end_of_month
    assert_equal Date.new(2005, 4, 30), Date.new(2005, 4, 20).end_of_month
  end

  def test_last_year_in_leap_years
    assert_equal Date.new(1999, 2, 28), Date.new(2000, 2, 29).last_year
  end

  def test_last_year_in_calendar_reform
    assert_equal Date.new(1582, 10, 4), Date.new(1583, 10, 14).last_year
  end

  def test_advance
    assert_equal Date.new(2006, 2, 28), Date.new(2005, 2, 28).advance(years: 1)
    assert_equal Date.new(2005, 6, 28), Date.new(2005, 2, 28).advance(months: 4)
    assert_equal Date.new(2005, 3, 21), Date.new(2005, 2, 28).advance(weeks: 3)
    assert_equal Date.new(2005, 3, 5), Date.new(2005, 2, 28).advance(days: 5)
    assert_equal Date.new(2012, 9, 28), Date.new(2005, 2, 28).advance(years: 7, months: 7)
    assert_equal Date.new(2013, 10, 3), Date.new(2005, 2, 28).advance(years: 7, months: 19, days: 5)
    assert_equal Date.new(2013, 10, 17), Date.new(2005, 2, 28).advance(years: 7, months: 19, weeks: 2, days: 5)
    assert_equal Date.new(2005, 2, 28), Date.new(2004, 2, 29).advance(years: 1) # leap day plus one year
  end

  def test_advance_does_first_years_and_then_days
    assert_equal Date.new(2012, 2, 29), Date.new(2011, 2, 28).advance(years: 1, days: 1)
    # If day was done first we would jump to 2012-03-01 instead.
  end

  def test_advance_does_first_months_and_then_days
    assert_equal Date.new(2010, 3, 29), Date.new(2010, 2, 28).advance(months: 1, days: 1)
    # If day was done first we would jump to 2010-04-01 instead.
  end

  def test_advance_in_calendar_reform
    assert_equal Date.new(1582, 10, 15), Date.new(1582, 10, 4).advance(days: 1)
    assert_equal Date.new(1582, 10, 4), Date.new(1582, 10, 15).advance(days: -1)
    5.upto(14) do |day|
      assert_equal Date.new(1582, 10, 4), Date.new(1582, 9, day).advance(months: 1)
      assert_equal Date.new(1582, 10, 4), Date.new(1582, 11, day).advance(months: -1)
      assert_equal Date.new(1582, 10, 4), Date.new(1581, 10, day).advance(years: 1)
      assert_equal Date.new(1582, 10, 4), Date.new(1583, 10, day).advance(years: -1)
    end
  end

  def test_last_week
    assert_equal Date.new(2005, 5, 9), Date.new(2005, 5, 17).last_week
    assert_equal Date.new(2006, 12, 25), Date.new(2007, 1, 7).last_week
    assert_equal Date.new(2010, 2, 12), Date.new(2010, 2, 19).last_week(:friday)
    assert_equal Date.new(2010, 2, 13), Date.new(2010, 2, 19).last_week(:saturday)
    assert_equal Date.new(2010, 2, 27), Date.new(2010, 3, 4).last_week(:saturday)
  end

  def test_next_week_in_calendar_reform
    assert_equal Date.new(1582, 10, 15), Date.new(1582, 9, 30).next_week(:friday)
    assert_equal Date.new(1582, 10, 18), Date.new(1582, 10, 4).next_week
  end

  def test_last_quarter_on_31st
    assert_equal Date.new(2004, 2, 29), Date.new(2004, 5, 31).last_quarter
  end

  def test_yesterday_constructor
    assert_equal Date.current - 1, Date.yesterday
  end

  def test_yesterday_constructor_when_zone_is_not_set
    with_env_tz "UTC" do
      with_tz_default do
        assert_equal(Date.today - 1, Date.yesterday)
      end
    end
  end

  def test_yesterday_constructor_when_zone_is_set
    with_env_tz "UTC" do
      with_tz_default ActiveSupport::TimeZone["Eastern Time (US & Canada)"] do # UTC -5
        Time.stub(:now, Time.local(2000, 1, 1)) do
          assert_equal Date.new(1999, 12, 30), Date.yesterday
        end
      end
    end
  end

  def test_tomorrow_constructor
    assert_equal Date.current + 1, Date.tomorrow
  end

  def test_tomorrow_constructor_when_zone_is_not_set
    with_env_tz "UTC" do
      with_tz_default do
        assert_equal(Date.today + 1, Date.tomorrow)
      end
    end
  end

  def test_tomorrow_constructor_when_zone_is_set
    with_env_tz "UTC" do
      with_tz_default ActiveSupport::TimeZone["Europe/Paris"] do # UTC +1
        Time.stub(:now, Time.local(1999, 12, 31, 23)) do
          assert_equal Date.new(2000, 1, 2), Date.tomorrow
        end
      end
    end
  end

  def test_since
    assert_equal Time.local(2005, 2, 21, 0, 0, 45), Date.new(2005, 2, 21).since(45)
  end

  def test_since_when_zone_is_set
    zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    with_env_tz "UTC" do
      with_tz_default zone do
        assert_equal zone.local(2005, 2, 21, 0, 0, 45), Date.new(2005, 2, 21).since(45)
        assert_equal zone, Date.new(2005, 2, 21).since(45).time_zone
      end
    end
  end

  def test_ago
    assert_equal Time.local(2005, 2, 20, 23, 59, 15), Date.new(2005, 2, 21).ago(45)
  end

  def test_ago_when_zone_is_set
    zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    with_env_tz "UTC" do
      with_tz_default zone do
        assert_equal zone.local(2005, 2, 20, 23, 59, 15), Date.new(2005, 2, 21).ago(45)
        assert_equal zone, Date.new(2005, 2, 21).ago(45).time_zone
      end
    end
  end

  def test_beginning_of_day
    assert_equal Time.local(2005, 2, 21, 0, 0, 0), Date.new(2005, 2, 21).beginning_of_day
  end

  def test_middle_of_day
    assert_equal Time.local(2005, 2, 21, 12, 0, 0), Date.new(2005, 2, 21).middle_of_day
  end

  def test_beginning_of_day_when_zone_is_set
    zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    with_env_tz "UTC" do
      with_tz_default zone do
        assert_equal zone.local(2005, 2, 21, 0, 0, 0), Date.new(2005, 2, 21).beginning_of_day
        assert_equal zone, Date.new(2005, 2, 21).beginning_of_day.time_zone
      end
    end
  end

  def test_end_of_day
    assert_equal Time.local(2005, 2, 21, 23, 59, 59, Rational(999999999, 1000)), Date.new(2005, 2, 21).end_of_day
  end

  def test_end_of_day_when_zone_is_set
    zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    with_env_tz "UTC" do
      with_tz_default zone do
        assert_equal zone.local(2005, 2, 21, 23, 59, 59, Rational(999999999, 1000)), Date.new(2005, 2, 21).end_of_day
        assert_equal zone, Date.new(2005, 2, 21).end_of_day.time_zone
      end
    end
  end

  def test_all_day
    beginning_of_day = Time.local(2011, 6, 7, 0, 0, 0)
    end_of_day = Time.local(2011, 6, 7, 23, 59, 59, Rational(999999999, 1000))
    assert_equal beginning_of_day..end_of_day, Date.new(2011, 6, 7).all_day
  end

  def test_all_day_when_zone_is_set
    zone = ActiveSupport::TimeZone["Hawaii"]
    with_env_tz "UTC" do
      with_tz_default zone do
        beginning_of_day = zone.local(2011, 6, 7, 0, 0, 0)
        end_of_day = zone.local(2011, 6, 7, 23, 59, 59, Rational(999999999, 1000))
        assert_equal beginning_of_day..end_of_day, Date.new(2011, 6, 7).all_day
      end
    end
  end

  def test_all_week
    assert_equal Date.new(2011, 6, 6)..Date.new(2011, 6, 12), Date.new(2011, 6, 7).all_week
    assert_equal Date.new(2011, 6, 5)..Date.new(2011, 6, 11), Date.new(2011, 6, 7).all_week(:sunday)
  end

  def test_all_month
    assert_equal Date.new(2011, 6, 1)..Date.new(2011, 6, 30), Date.new(2011, 6, 7).all_month
  end

  def test_all_quarter
    assert_equal Date.new(2011, 4, 1)..Date.new(2011, 6, 30), Date.new(2011, 6, 7).all_quarter
  end

  def test_all_year
    assert_equal Date.new(2011, 1, 1)..Date.new(2011, 12, 31), Date.new(2011, 6, 7).all_year
  end

  def test_xmlschema
    with_env_tz "US/Eastern" do
      assert_match(/^1980-02-28T00:00:00-05:?00$/, Date.new(1980, 2, 28).xmlschema)
      assert_match(/^1980-06-28T00:00:00-04:?00$/, Date.new(1980, 6, 28).xmlschema)
      # these tests are only of interest on platforms where older dates #to_time fail over to DateTime
      if ::DateTime === Date.new(1880, 6, 28).to_time
        assert_match(/^1880-02-28T00:00:00-05:?00$/, Date.new(1880, 2, 28).xmlschema)
        assert_match(/^1880-06-28T00:00:00-05:?00$/, Date.new(1880, 6, 28).xmlschema) # DateTimes aren't aware of DST rules
      end
    end
  end

  def test_xmlschema_when_zone_is_set
    with_env_tz "UTC" do
      with_tz_default ActiveSupport::TimeZone["Eastern Time (US & Canada)"] do # UTC -5
        assert_match(/^1980-02-28T00:00:00-05:?00$/, Date.new(1980, 2, 28).xmlschema)
        assert_match(/^1980-06-28T00:00:00-04:?00$/, Date.new(1980, 6, 28).xmlschema)
      end
    end
  end

  def test_past
    Date.stub(:current, Date.new(2000, 1, 1)) do
      assert_equal true, Date.new(1999, 12, 31).past?
      assert_equal false, Date.new(2000, 1, 1).past?
      assert_equal false, Date.new(2000, 1, 2).past?
    end
  end

  def test_future
    Date.stub(:current, Date.new(2000, 1, 1)) do
      assert_equal false, Date.new(1999, 12, 31).future?
      assert_equal false, Date.new(2000, 1, 1).future?
      assert_equal true, Date.new(2000, 1, 2).future?
    end
  end

  def test_current_returns_date_today_when_zone_not_set
    with_env_tz "US/Central" do
      Time.stub(:now, Time.local(1999, 12, 31, 23)) do
        assert_equal Date.today, Date.current
      end
    end
  end

  def test_current_returns_time_zone_today_when_zone_is_set
    Time.zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    with_env_tz "US/Central" do
      assert_equal ::Time.zone.today, Date.current
    end
  ensure
    Time.zone = nil
  end

  def test_upcoming_date_returns_current_year_when_date_has_not_passed
    Time.stub(:now, Time.local(2024, 6, 15)) do # June 15, 2024
      assert_equal Date.new(2024, 12, 25), Date.upcoming_date(12, 25) # Christmas
      assert_equal Date.new(2024, 7, 4), Date.upcoming_date(7, 4) # July 4th
      assert_equal Date.new(2024, 6, 15), Date.upcoming_date(6, 15) # Same day
    end
  end

  def test_upcoming_date_returns_next_year_when_date_has_already_passed
    Time.stub(:now, Time.local(2024, 6, 15)) do # June 15, 2024
      assert_equal Date.new(2025, 1, 1), Date.upcoming_date(1, 1) # New Year
      assert_equal Date.new(2025, 3, 15), Date.upcoming_date(3, 15) # March 15
      assert_equal Date.new(2025, 6, 14), Date.upcoming_date(6, 14) # June 14 (yesterday)
    end
  end

  def test_upcoming_date_with_leap_year
    Time.stub(:now, Time.local(2024, 2, 28)) do # Feb 28, 2024 (leap year)
      assert_equal Date.new(2024, 2, 29), Date.upcoming_date(2, 29) # Feb 29 in leap year
    end

    Time.stub(:now, Time.local(2023, 2, 28)) do # Feb 28, 2023 (not leap year)
      assert_equal Date.new(2024, 2, 29), Date.upcoming_date(2, 29) # Feb 29 in next leap year
    end

    # Test jumping multiple years to find next leap year
    Time.stub(:now, Time.local(2021, 3, 1)) do # March 1, 2021 (after Feb 29 has passed, not a leap year)
      assert_equal Date.new(2024, 2, 29), Date.upcoming_date(2, 29) # Feb 29 in next leap year (3 years later)
    end

    # Test from a century year that's not a leap year (like 1900, 2100)
    Time.stub(:now, Time.local(2101, 1, 1)) do # 2100 is not a leap year (century rule)
      assert_equal Date.new(2104, 2, 29), Date.upcoming_date(2, 29) # Feb 29 in 2104 (next leap year)
    end
  end

  def test_upcoming_date_when_zone_is_not_set
    with_env_tz "UTC" do
      with_tz_default do
        Time.stub(:now, Time.local(2024, 6, 15)) do
          assert_equal Date.new(2024, 12, 25), Date.upcoming_date(12, 25)
          assert_equal Date.new(2025, 1, 1), Date.upcoming_date(1, 1)
        end
      end
    end
  end

  def test_upcoming_date_when_zone_is_set
    Time.zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"] # UTC -5
    with_env_tz "UTC" do
      Time.stub(:now, Time.local(2024, 12, 31, 23)) do # 11 PM UTC on Dec 31
        # In Eastern Time, it's still Dec 31 (6 PM), so Christmas next year
        assert_equal Date.new(2025, 12, 25), Date.upcoming_date(12, 25)
        # But New Year's Day is tomorrow in Eastern Time
        assert_equal Date.new(2025, 1, 1), Date.upcoming_date(1, 1)
      end
    end
  ensure
    Time.zone = nil
  end

  def test_upcoming_date_edge_cases
    # Test end of year
    Time.stub(:now, Time.local(2024, 12, 31, 23, 59, 59)) do
      assert_equal Date.new(2025, 1, 1), Date.upcoming_date(1, 1) # Next day
      assert_equal Date.new(2025, 12, 25), Date.upcoming_date(12, 25) # Christmas next year
    end

    # Test beginning of year
    Time.stub(:now, Time.local(2024, 1, 1, 0, 0, 1)) do # 1 second after midnight
      assert_equal Date.new(2024, 1, 1), Date.upcoming_date(1, 1) # Same day
      assert_equal Date.new(2024, 12, 25), Date.upcoming_date(12, 25) # Christmas this year
    end
  end

  def test_upcoming_date_with_invalid_parameters
    assert_raises(ArgumentError, "Invalid date: month 13, day 1") do
      Date.upcoming_date(13, 1)
    end

    assert_raises(ArgumentError, "Invalid date: month 1, day 32") do
      Date.upcoming_date(1, 32)
    end

    assert_raises(ArgumentError, "Invalid date: month 100, day 100") do
      Date.upcoming_date(100, 100)
    end
  end

  def test_date_advance_should_not_change_passed_options_hash
    options = { years: 3, months: 11, days: 2 }
    Date.new(2005, 2, 28).advance(options)
    assert_equal({ years: 3, months: 11, days: 2 }, options)
  end
end

class DateExtBehaviorTest < ActiveSupport::TestCase
  def test_date_acts_like_date
    assert_predicate Date.new, :acts_like_date?
  end

  def test_blank?
    assert_not_predicate Date.new, :blank?
  end

  def test_freeze_doesnt_clobber_memoized_instance_methods
    assert_nothing_raised do
      Date.today.freeze.inspect
    end
  end

  def test_can_freeze_twice
    assert_nothing_raised do
      Date.today.freeze.freeze
    end
  end
end
