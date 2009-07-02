require 'abstract_unit'
require 'active_support/time'

class DurationTest < ActiveSupport::TestCase
  def test_inspect
    assert_equal '0 seconds',                       0.seconds.inspect
    assert_equal '1 month',                         1.month.inspect
    assert_equal '1 month and 1 day',               (1.month + 1.day).inspect
    assert_equal '6 months and -2 days',            (6.months - 2.days).inspect
    assert_equal '10 seconds',                      10.seconds.inspect
    assert_equal '10 years, 2 months, and 1 day',   (10.years + 2.months + 1.day).inspect
    assert_equal '7 days',                          1.week.inspect
    assert_equal '14 days',                         1.fortnight.inspect
  end

  def test_minus_with_duration_does_not_break_subtraction_of_date_from_date
    assert_nothing_raised { Date.today - Date.today }
  end

  def test_plus_with_time
    assert_equal 1 + 1.second, 1.second + 1, "Duration + Numeric should == Numeric + Duration"
  end

  def test_argument_error
    begin
      1.second.ago('')
      flunk("no exception was raised")
    rescue ArgumentError => e
      assert_equal 'expected a time or date, got ""', e.message, "ensure ArgumentError is not being raised by dependencies.rb"
    rescue Exception
      flunk("ArgumentError should be raised, but we got #{$!.class} instead")
    end
  end

  def test_fractional_weeks
    assert_equal((86400 * 7) * 1.5, 1.5.weeks)
    assert_equal((86400 * 7) * 1.7, 1.7.weeks)
  end

  def test_fractional_days
    assert_equal 86400 * 1.5, 1.5.days
    assert_equal 86400 * 1.7, 1.7.days
  end

  def test_since_and_ago_with_fractional_days
    t = Time.local(2000)
    # since
    assert_equal 36.hours.since(t), 1.5.days.since(t)
    assert_in_delta((24 * 1.7).hours.since(t), 1.7.days.since(t), 1)
    # ago
    assert_equal 36.hours.ago(t), 1.5.days.ago(t)
    assert_in_delta((24 * 1.7).hours.ago(t), 1.7.days.ago(t), 1)
  end

  def test_since_and_ago_with_fractional_weeks
    t = Time.local(2000)
    # since
    assert_equal((7 * 36).hours.since(t), 1.5.weeks.since(t))
    assert_in_delta((7 * 24 * 1.7).hours.since(t), 1.7.weeks.since(t), 1)
    # ago
    assert_equal((7 * 36).hours.ago(t), 1.5.weeks.ago(t))
    assert_in_delta((7 * 24 * 1.7).hours.ago(t), 1.7.weeks.ago(t), 1)
  end

  def test_since_and_ago_anchored_to_time_now_when_time_zone_default_not_set
    Time.zone_default = nil
    with_env_tz 'US/Eastern' do
      Time.stubs(:now).returns Time.local(2000)
      # since
      assert_equal false, 5.seconds.since.is_a?(ActiveSupport::TimeWithZone)
      assert_equal Time.local(2000,1,1,0,0,5), 5.seconds.since
      # ago
      assert_equal false, 5.seconds.ago.is_a?(ActiveSupport::TimeWithZone)
      assert_equal Time.local(1999,12,31,23,59,55), 5.seconds.ago
    end
  end

  def test_since_and_ago_anchored_to_time_zone_now_when_time_zone_default_set
    Time.zone_default = ActiveSupport::TimeZone['Eastern Time (US & Canada)']
    with_env_tz 'US/Eastern' do
      Time.stubs(:now).returns Time.local(2000)
      # since
      assert_equal true, 5.seconds.since.is_a?(ActiveSupport::TimeWithZone)
      assert_equal Time.utc(2000,1,1,0,0,5), 5.seconds.since.time
      assert_equal 'Eastern Time (US & Canada)', 5.seconds.since.time_zone.name
      # ago
      assert_equal true, 5.seconds.ago.is_a?(ActiveSupport::TimeWithZone)
      assert_equal Time.utc(1999,12,31,23,59,55), 5.seconds.ago.time
      assert_equal 'Eastern Time (US & Canada)', 5.seconds.ago.time_zone.name
    end
  ensure
    Time.zone_default = nil
  end
  
  def test_adding_hours_across_dst_boundary
    with_env_tz 'CET' do
      assert_equal Time.local(2009,3,29,0,0,0) + 24.hours, Time.local(2009,3,30,1,0,0)
    end
  end
  
  def test_adding_day_across_dst_boundary
    with_env_tz 'CET' do
      assert_equal Time.local(2009,3,29,0,0,0) + 1.day, Time.local(2009,3,30,0,0,0)
    end
  end

  protected
    def with_env_tz(new_tz = 'US/Eastern')
      old_tz, ENV['TZ'] = ENV['TZ'], new_tz
      yield
    ensure
      old_tz ? ENV['TZ'] = old_tz : ENV.delete('TZ')
    end
end
