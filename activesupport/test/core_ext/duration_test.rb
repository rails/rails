require 'abstract_unit'
require 'active_support/inflector'
require 'active_support/time'
require 'active_support/json'
require 'time_zone_test_helpers'

class DurationTest < ActiveSupport::TestCase
  include TimeZoneTestHelpers

  def test_is_a
    d = 1.day
    assert d.is_a?(ActiveSupport::Duration)
    assert_kind_of ActiveSupport::Duration, d
    assert_kind_of Numeric, d
    assert_kind_of Integer, d
    assert !d.is_a?(Hash)

    k = Class.new
    class << k; undef_method :== end
    assert !d.is_a?(k)
  end

  def test_instance_of
    assert 1.minute.instance_of?(1.class)
    assert 2.days.instance_of?(ActiveSupport::Duration)
    assert !3.second.instance_of?(Numeric)
  end

  def test_threequals
    assert ActiveSupport::Duration === 1.day
    assert !(ActiveSupport::Duration === 1.day.to_i)
    assert !(ActiveSupport::Duration === 'foo')
  end

  def test_equals
    assert 1.day == 1.day
    assert 1.day == 1.day.to_i
    assert 1.day.to_i == 1.day
    assert !(1.day == 'foo')
  end

  def test_to_s
    assert_equal "1", 1.second.to_s
  end

  def test_eql
    rubinius_skip "Rubinius' #eql? definition relies on #instance_of? " \
                  "which behaves oddly for the sake of backward-compatibility."

    assert 1.minute.eql?(1.minute)
    assert 1.minute.eql?(60.seconds)
    assert 2.days.eql?(48.hours)
    assert !1.second.eql?(1)
    assert !1.eql?(1.second)
    assert 1.minute.eql?(180.seconds - 2.minutes)
    assert !1.minute.eql?(60)
    assert !1.minute.eql?('foo')
  end

  def test_inspect
    assert_equal '0 seconds',                       0.seconds.inspect
    assert_equal '1 month',                         1.month.inspect
    assert_equal '1 month and 1 day',               (1.month + 1.day).inspect
    assert_equal '6 months and -2 days',            (6.months - 2.days).inspect
    assert_equal '10 seconds',                      10.seconds.inspect
    assert_equal '10 years, 2 months, and 1 day',   (10.years + 2.months + 1.day).inspect
    assert_equal '10 years, 2 months, and 1 day',   (10.years + 1.month  + 1.day + 1.month).inspect
    assert_equal '10 years, 2 months, and 1 day',   (1.day + 10.years + 2.months).inspect
    assert_equal '7 days',                          1.week.inspect
    assert_equal '14 days',                         1.fortnight.inspect
  end

  def test_inspect_locale
    current_locale = I18n.default_locale
    I18n.default_locale = :de
    I18n.backend.store_translations(:de, { support: { array: { last_word_connector: ' und ' } } })
    assert_equal '10 years, 1 month und 1 day', (10.years + 1.month  + 1.day).inspect
  ensure
    I18n.default_locale = current_locale
  end

  def test_minus_with_duration_does_not_break_subtraction_of_date_from_date
    assert_nothing_raised { Date.today - Date.today }
  end

  def test_plus_with_time
    assert_equal 1 + 1.second, 1.second + 1, "Duration + Numeric should == Numeric + Duration"
  end

  def test_argument_error
    e = assert_raise ArgumentError do
      1.second.ago('')
    end
    assert_equal 'expected a time or date, got ""', e.message, "ensure ArgumentError is not being raised by dependencies.rb"
  end

  def test_fractional_weeks
    assert_equal((86400 * 7) * 1.5, 1.5.weeks)
    assert_equal((86400 * 7) * 1.7, 1.7.weeks)
  end

  def test_fractional_days
    assert_equal 86400 * 1.5, 1.5.days
    assert_equal 86400 * 1.7, 1.7.days
  end

  def test_since_and_ago
    t = Time.local(2000)
    assert_equal t + 1, 1.second.since(t)
    assert_equal t - 1, 1.second.ago(t)
  end

  def test_since_and_ago_without_argument
    now = Time.now
    assert 1.second.since >= now + 1
    now = Time.now
    assert 1.second.ago >= now - 1
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

  def test_since_and_ago_anchored_to_time_now_when_time_zone_is_not_set
    Time.zone = nil
    with_env_tz 'US/Eastern' do
      Time.stubs(:now).returns Time.local(2000)
      # since
      assert_not_instance_of ActiveSupport::TimeWithZone, 5.seconds.since
      assert_equal Time.local(2000,1,1,0,0,5), 5.seconds.since
      # ago
      assert_not_instance_of ActiveSupport::TimeWithZone, 5.seconds.ago
      assert_equal Time.local(1999,12,31,23,59,55), 5.seconds.ago
    end
  end

  def test_since_and_ago_anchored_to_time_zone_now_when_time_zone_is_set
    Time.zone = ActiveSupport::TimeZone['Eastern Time (US & Canada)']
    with_env_tz 'US/Eastern' do
      Time.stubs(:now).returns Time.local(2000)
      # since
      assert_instance_of ActiveSupport::TimeWithZone, 5.seconds.since
      assert_equal Time.utc(2000,1,1,0,0,5), 5.seconds.since.time
      assert_equal 'Eastern Time (US & Canada)', 5.seconds.since.time_zone.name
      # ago
      assert_instance_of ActiveSupport::TimeWithZone, 5.seconds.ago
      assert_equal Time.utc(1999,12,31,23,59,55), 5.seconds.ago.time
      assert_equal 'Eastern Time (US & Canada)', 5.seconds.ago.time_zone.name
    end
  ensure
    Time.zone = nil
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

  def test_delegation_with_block_works
    counter = 0
    assert_nothing_raised do
      1.minute.times {counter += 1}
    end
    assert_equal counter, 60
  end

  def test_as_json
    assert_equal 172800, 2.days.as_json
  end

  def test_to_json
    assert_equal '172800', 2.days.to_json
  end

  def test_case_when
    cased = case 1.day when 1.day then "ok" end
    assert_equal cased, "ok"
  end

  def test_respond_to
    assert_respond_to 1.day, :since
    assert_respond_to 1.day, :zero?
  end

  def test_hash
    assert_equal 1.minute.hash, 60.seconds.hash
  end

  def test_comparable
    assert_equal(-1, (0.seconds <=> 1.second))
    assert_equal(-1, (1.second <=> 1.minute))
    assert_equal(-1, (1 <=> 1.minute))
    assert_equal(0, (0.seconds <=> 0.seconds))
    assert_equal(0, (0.seconds <=> 0.minutes))
    assert_equal(0, (1.second <=> 1.second))
    assert_equal(1, (1.second <=> 0.second))
    assert_equal(1, (1.minute <=> 1.second))
    assert_equal(1, (61 <=> 1.minute))
  end
end
