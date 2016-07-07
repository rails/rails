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
    assert 1.minute.instance_of?(Fixnum)
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
    assert_equal '7 days',                          7.days.inspect
    assert_equal '1 week',                          1.week.inspect
    assert_equal '2 weeks',                         1.fortnight.inspect
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

  def test_time_plus_duration_returns_same_time_datatype
    twz = ActiveSupport::TimeWithZone.new(nil, ActiveSupport::TimeZone['Moscow'] , Time.utc(2016,4,28,00,45))
    now = Time.now.utc
    %w( second minute hour day week month year ).each do |unit|
      assert_equal((now + 1.send(unit)).class, Time, "Time + 1.#{unit} must be Time")
      assert_equal((twz + 1.send(unit)).class, ActiveSupport::TimeWithZone, "TimeWithZone + 1.#{unit} must be TimeWithZone")
    end
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
      Time.stub(:now, Time.local(2000)) do
        # since
        assert_not_instance_of ActiveSupport::TimeWithZone, 5.seconds.since
        assert_equal Time.local(2000,1,1,0,0,5), 5.seconds.since
        # ago
        assert_not_instance_of ActiveSupport::TimeWithZone, 5.seconds.ago
        assert_equal Time.local(1999,12,31,23,59,55), 5.seconds.ago
      end
    end
  end

  def test_since_and_ago_anchored_to_time_zone_now_when_time_zone_is_set
    Time.zone = ActiveSupport::TimeZone['Eastern Time (US & Canada)']
    with_env_tz 'US/Eastern' do
      Time.stub(:now, Time.local(2000)) do
        # since
        assert_instance_of ActiveSupport::TimeWithZone, 5.seconds.since
        assert_equal Time.utc(2000,1,1,0,0,5), 5.seconds.since.time
        assert_equal 'Eastern Time (US & Canada)', 5.seconds.since.time_zone.name
        # ago
        assert_instance_of ActiveSupport::TimeWithZone, 5.seconds.ago
        assert_equal Time.utc(1999,12,31,23,59,55), 5.seconds.ago.time
        assert_equal 'Eastern Time (US & Canada)', 5.seconds.ago.time_zone.name
      end
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

  # ISO8601 string examples are taken from ISO8601 gem at https://github.com/arnau/ISO8601/blob/b93d466840/spec/iso8601/duration_spec.rb
  # published under the conditions of MIT license at https://github.com/arnau/ISO8601/blob/b93d466840/LICENSE
  #
  # Copyright (c) 2012-2014 Arnau Siches
  #
  # MIT License
  #
  # Permission is hereby granted, free of charge, to any person obtaining
  # a copy of this software and associated documentation files (the
  # "Software"), to deal in the Software without restriction, including
  # without limitation the rights to use, copy, modify, merge, publish,
  # distribute, sublicense, and/or sell copies of the Software, and to
  # permit persons to whom the Software is furnished to do so, subject to
  # the following conditions:
  #
  # The above copyright notice and this permission notice shall be
  # included in all copies or substantial portions of the Software.
  #
  # THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
  # EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
  # MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
  # NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
  # LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
  # OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
  # WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

  def test_iso8601_parsing_wrong_patterns_with_raise
    invalid_patterns = ['', 'P', 'PT', 'P1YT', 'T', 'PW', 'P1Y1W', '~P1Y', '.P1Y', 'P1.5Y0.5M', 'P1.5Y1M', 'P1.5MT10.5S']
    invalid_patterns.each do |pattern|
      assert_raise ActiveSupport::Duration::ISO8601Parser::ParsingError, pattern.inspect do
        ActiveSupport::Duration.parse(pattern)
      end
    end
  end

  def test_iso8601_output
    expectations = [
      ['P1Y',           1.year                           ],
      ['P1W',           1.week                           ],
      ['P1Y1M',         1.year + 1.month                 ],
      ['P1Y1M1D',       1.year + 1.month + 1.day         ],
      ['-P1Y1D',        -1.year - 1.day                  ],
      ['P1Y-1DT-1S',    1.year - 1.day - 1.second        ], # Parts with different signs are exists in PostgreSQL interval datatype.
      ['PT1S',          1.second                         ],
      ['PT1.4S',        (1.4).seconds                    ],
      ['P1Y1M1DT1H',    1.year + 1.month + 1.day + 1.hour],
    ]
    expectations.each do |expected_output, duration|
      assert_equal expected_output, duration.iso8601, expected_output.inspect
    end
  end

  def test_iso8601_output_precision
    expectations = [
        [nil, 'P1Y1MT5.55S',  1.year + 1.month + (5.55).seconds ],
        [0,   'P1Y1MT6S',     1.year + 1.month + (5.55).seconds ],
        [1,   'P1Y1MT5.5S',   1.year + 1.month + (5.55).seconds ],
        [2,   'P1Y1MT5.55S',  1.year + 1.month + (5.55).seconds ],
        [3,   'P1Y1MT5.550S', 1.year + 1.month + (5.55).seconds ],
        [nil, 'PT1S',         1.second                          ],
        [2,   'PT1.00S',      1.second                          ],
        [nil, 'PT1.4S',       (1.4).seconds                     ],
        [0,   'PT1S',         (1.4).seconds                     ],
        [1,   'PT1.4S',       (1.4).seconds                     ],
        [5,   'PT1.40000S',   (1.4).seconds                     ],
    ]
    expectations.each do |precision, expected_output, duration|
      assert_equal expected_output, duration.iso8601(precision: precision), expected_output.inspect
    end
  end

  def test_iso8601_output_and_reparsing
    patterns = %w[
      P1Y P0.5Y P0,5Y P1Y1M P1Y0.5M P1Y0,5M P1Y1M1D P1Y1M0.5D P1Y1M0,5D P1Y1M1DT1H P1Y1M1DT0.5H P1Y1M1DT0,5H P1W +P1Y -P1Y
      P1Y1M1DT1H1M P1Y1M1DT1H0.5M P1Y1M1DT1H0,5M P1Y1M1DT1H1M1S P1Y1M1DT1H1M1.0S P1Y1M1DT1H1M1,0S P-1Y-2M3DT-4H-5M-6S
    ]
    # That could be weird, but if we parse P1Y1M0.5D and output it to ISO 8601, we'll get P1Y1MT12.0H.
    # So we check that initially parsed and reparsed duration added to time will result in the same time.
    time = Time.current
    patterns.each do |pattern|
      duration = ActiveSupport::Duration.parse(pattern)
      assert_equal time+duration, time+ActiveSupport::Duration.parse(duration.iso8601), pattern.inspect
    end
  end
end
