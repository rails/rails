# frozen_string_literal: true

require "abstract_unit"
require "active_support/time"
require "core_ext/date_and_time_behavior"
require "time_zone_test_helpers"

class DateExtCalculationsTest < ActiveSupport::TestCase
  def date_time_init(year, month, day, *_args)
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

  def test_to_s
    date = Date.new(2005, 2, 21)
    assert_equal "2005-02-21",          date.to_s
    assert_equal "21 Feb",              date.to_s(:short)
    assert_equal "February 21, 2005",   date.to_s(:long)
    assert_equal "February 21st, 2005", date.to_s(:long_ordinal)
    assert_equal "2005-02-21",          date.to_s(:db)
    assert_equal "21 Feb 2005",         date.to_s(:rfc822)
    assert_equal "2005-02-21",          date.to_s(:iso8601)
  end

  def test_to_s_with_single_digit_day
    date = Date.new(2005, 2, 1)
    assert_equal "2005-02-01",          date.to_s
    assert_equal "01 Feb",              date.to_s(:short)
    assert_equal "February 01, 2005",   date.to_s(:long)
    assert_equal "February 1st, 2005",  date.to_s(:long_ordinal)
    assert_equal "2005-02-01",          date.to_s(:db)
    assert_equal "01 Feb 2005",         date.to_s(:rfc822)
    assert_equal "2005-02-01",          date.to_s(:iso8601)
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

  def test_prev_year_in_leap_years
    assert_equal Date.new(1999, 2, 28), Date.new(2000, 2, 29).prev_year
  end

  def test_prev_year_in_calendar_reform
    assert_equal Date.new(1582, 10, 4), Date.new(1583, 10, 14).prev_year
  end

  def test_last_year_in_leap_years
    assert_equal Date.new(1999, 2, 28), Date.new(2000, 2, 29).last_year
  end

  def test_last_year_in_calendar_reform
    assert_equal Date.new(1582, 10, 4), Date.new(1583, 10, 14).last_year
  end

  def test_next_year_in_leap_years
    assert_equal Date.new(2001, 2, 28), Date.new(2000, 2, 29).next_year
  end

  def test_next_year_in_calendar_reform
    assert_equal Date.new(1582, 10, 4), Date.new(1581, 10, 10).next_year
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
