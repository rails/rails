# frozen_string_literal: true

require_relative "../abstract_unit"
require "active_support/time"
require "active_support/core_ext/numeric"
require "active_support/core_ext/range"

class RangeTest < ActiveSupport::TestCase
  def test_to_fs_from_dates
    date_range = Date.new(2005, 12, 10)..Date.new(2005, 12, 12)
    assert_equal "BETWEEN '2005-12-10' AND '2005-12-12'", date_range.to_fs(:db)
    assert_equal "BETWEEN '2005-12-10' AND '2005-12-12'", date_range.to_formatted_s(:db)
  end

  def test_to_fs_from_times
    date_range = Time.utc(2005, 12, 10, 15, 30)..Time.utc(2005, 12, 10, 17, 30)
    assert_equal "BETWEEN '2005-12-10 15:30:00' AND '2005-12-10 17:30:00'", date_range.to_fs(:db)
  end

  def test_to_fs_with_alphabets
    assert_equal "BETWEEN 'a' AND 'z'", ("a".."z").to_fs(:db)
    assert_equal ">= 'a'", ("a"..).to_fs(:db)
    assert_equal "<= 'z'", (.."z").to_fs(:db)
  end

  def test_to_fs_with_numeric
    assert_equal "BETWEEN '1' AND '100'", (1..100).to_fs(:db)
    assert_equal ">= '1'", (1..).to_fs(:db)
    assert_equal "<= '100'", (..100).to_fs(:db)
  end

  def test_to_fs_with_format_invalid_format
    number_range = (1..100)

    assert_equal "1..100", number_range.to_fs(:not_existent)
  end

  def test_date_range
    assert_instance_of Range, DateTime.new..DateTime.new
    assert_instance_of Range, DateTime::Infinity.new..DateTime::Infinity.new
    assert_instance_of Range, DateTime.new..DateTime::Infinity.new
  end

  def test_overlap_last_inclusive
    assert((1..5).overlap?(5..10))
  end

  def test_overlap_last_exclusive
    assert_not (1...5).overlap?(5..10)
  end

  def test_overlap_first_inclusive
    assert((5..10).overlap?(1..5))
  end

  def test_overlap_first_exclusive
    assert_not (5..10).overlap?(1...5)
  end

  def test_overlap_with_beginless_range
    assert((1..5).overlap?(..10))
  end

  def test_overlap_with_two_beginless_ranges
    assert((..5).overlap?(..10))
  end

  def test_overlaps_alias
    assert (1..5).overlaps?(5..10)
    assert_not (1...5).overlaps?(6..10)
  end

  def test_overlap_behaves_like_ruby
    assert_not_operator(0..2, :overlap?, -2..-1)
    assert_not_operator(0..2, :overlap?, -2...0)
    assert_operator(0..2, :overlap?, -1..0)
    assert_operator(0..2, :overlap?, 1..2)
    assert_operator(0..2, :overlap?, 2..3)
    assert_not_operator(0..2, :overlap?, 3..4)
    assert_not_operator(0...2, :overlap?, 2..3)
    assert_operator(..0, :overlap?, -1..0)
    assert_operator(...0, :overlap?, -1..0)
    assert_operator(..0, :overlap?, 0..1)
    assert_operator(..0, :overlap?, ..1)
    assert_not_operator(..0, :overlap?, 1..2)
    assert_not_operator(...0, :overlap?, 0..1)
    assert_not_operator(0.., :overlap?, -2..-1)
    assert_not_operator(0.., :overlap?, ...0)
    assert_operator(0.., :overlap?, -1..0)
    assert_operator(0.., :overlap?, ..0)
    assert_operator(0.., :overlap?, 0..1)
    assert_operator(0.., :overlap?, 1..2)
    assert_operator(0.., :overlap?, 1..)

    assert_not_operator((1..3), :overlap?, ("a".."d"))

    assert_raise(TypeError) { (0..).overlap?(1) }
    assert_raise(TypeError) { (0..).overlap?(nil) }

    assert_operator((1..3), :overlap?, (2..4))
    assert_operator((1...3), :overlap?, (2..3))
    assert_operator((2..3), :overlap?, (1..2))
    assert_operator((..3), :overlap?, (3..))
    assert_operator((nil..nil), :overlap?, (3..))
    assert_operator((nil...nil), :overlap?, (nil..))

    assert_raise(TypeError) { (1..3).overlap?(1) }

    assert_not_operator((1..2), :overlap?, (2...2))
    assert_not_operator((2...2), :overlap?, (1..2))

    assert_not_operator((4..1), :overlap?, (2..3))
    assert_not_operator((4..1), :overlap?, (..3))
    assert_not_operator((4..1), :overlap?, (2..))

    assert_not_operator((1..4), :overlap?, (3..2))
    assert_not_operator((..4), :overlap?, (3..2))
    assert_not_operator((1..), :overlap?, (3..2))

    assert_not_operator((4..5), :overlap?, (2..3))
    assert_not_operator((4..5), :overlap?, (2...4))

    assert_not_operator((1..2), :overlap?, (3..4))
    assert_not_operator((1...3), :overlap?, (3..4))

    assert_not_operator((4..5), :overlap?, (2..3))
    assert_not_operator((4..5), :overlap?, (2...4))

    assert_not_operator((1..2), :overlap?, (3..4))
    assert_not_operator((1...3), :overlap?, (3..4))
    assert_not_operator((...3), :overlap?, (3..))
  end

  def test_should_include_identical_inclusive
    assert((1..10).include?(1..10))
  end

  def test_should_include_identical_exclusive
    assert((1...10).include?(1...10))
  end

  def test_should_include_other_with_exclusive_end
    assert((1..10).include?(1...11))
  end

  def test_include_returns_false_for_backwards
    assert_not((1..10).include?(5..3))
  end

  # Match quirky plain-Ruby behavior
  def test_include_returns_false_for_empty_exclusive_end
    assert_not((1..5).include?(3...3))
  end

  def test_include_with_endless_range
    assert((1..).include?(2))
  end

  def test_should_include_range_with_endless_range
    assert((1..).include?(2..4))
  end

  def test_should_not_include_range_with_endless_range
    assert_not((1..).include?(0..4))
  end

  def test_include_with_beginless_range
    assert((..2).include?(1))
  end

  def test_should_include_range_with_beginless_range
    assert((..2).include?(-1..1))
  end

  def test_should_not_include_range_with_beginless_range
    assert_not((..2).include?(-1..3))
  end

  def test_should_compare_identical_inclusive
    assert((1..10) === (1..10))
  end

  def test_should_compare_identical_exclusive
    assert((1...10) === (1...10))
  end

  def test_should_compare_other_with_exclusive_end
    assert((1..10) === (1...11))
  end

  def test_compare_returns_false_for_backwards
    assert_not((1..10) === (5..3))
  end

  # Match quirky plain-Ruby behavior
  def test_compare_returns_false_for_empty_exclusive_end
    assert_not((1..5) === (3...3))
  end

  def test_should_compare_range_with_endless_range
    assert((1..) === (2..4))
  end

  def test_should_not_compare_range_with_endless_range
    assert_not((1..) === (0..4))
  end

  def test_should_compare_range_with_beginless_range
    assert((..2) === (-1..1))
  end

  def test_should_not_compare_range_with_beginless_range
    assert_not((..2) === (-1..3))
  end

  def test_exclusive_end_should_not_include_identical_with_inclusive_end
    assert_not_includes (1...10), 1..10
  end

  def test_should_not_include_overlapping_first
    assert_not_includes (2..8), 1..3
  end

  def test_should_not_include_overlapping_last
    assert_not_includes (2..8), 5..9
  end

  def test_should_include_identical_exclusive_with_floats
    assert((1.0...10.0).include?(1.0...10.0))
  end

  def test_cover_is_not_override
    range = (1..3)
    assert range.method(:include?) != range.method(:cover?)
  end

  def test_overlap_on_time
    time_range_1 = Time.utc(2005, 12, 10, 15, 30)..Time.utc(2005, 12, 10, 17, 30)
    time_range_2 = Time.utc(2005, 12, 10, 17, 00)..Time.utc(2005, 12, 10, 18, 00)
    assert time_range_1.overlap?(time_range_2)
  end

  def test_no_overlap_on_time
    time_range_1 = Time.utc(2005, 12, 10, 15, 30)..Time.utc(2005, 12, 10, 17, 30)
    time_range_2 = Time.utc(2005, 12, 10, 17, 31)..Time.utc(2005, 12, 10, 18, 00)
    assert_not time_range_1.overlap?(time_range_2)
  end

  def test_each_on_time_with_zone
    twz = ActiveSupport::TimeWithZone.new(nil, ActiveSupport::TimeZone["Eastern Time (US & Canada)"], Time.utc(2006, 11, 28, 10, 30))
    assert_raises TypeError do
      ((twz - 1.hour)..twz).each { }
    end
  end

  if RUBY_VERSION < "3.4"
    def test_step_on_time_with_zone
      twz = ActiveSupport::TimeWithZone.new(nil, ActiveSupport::TimeZone["Eastern Time (US & Canada)"], Time.utc(2006, 11, 28, 10, 30))
      assert_raises TypeError do
        ((twz - 1.hour)..twz).step(1) { }
      end
    end
  else
    def test_step_on_time_with_zone
      twz = ActiveSupport::TimeWithZone.new(nil, ActiveSupport::TimeZone["Eastern Time (US & Canada)"], Time.utc(2006, 11, 28, 10, 30))

      assert_equal [twz, twz + 15.minutes, twz + 30.minutes], (twz..).step(15.minutes).first(3)
    end
  end

  def test_cover_on_time_with_zone
    twz = ActiveSupport::TimeWithZone.new(nil, ActiveSupport::TimeZone["Eastern Time (US & Canada)"], Time.utc(2006, 11, 28, 10, 30))
    assert ((twz - 1.hour)..twz).cover?(twz)
  end

  def test_case_equals_on_time_with_zone
    twz = ActiveSupport::TimeWithZone.new(nil, ActiveSupport::TimeZone["Eastern Time (US & Canada)"], Time.utc(2006, 11, 28, 10, 30))
    assert ((twz - 1.hour)..twz) === twz
  end

  def test_date_time_with_each
    datetime = DateTime.now
    assert(((datetime - 1.hour)..datetime).each { })
  end

  def test_date_time_with_step
    datetime = DateTime.now
    assert(((datetime - 1.hour)..datetime).step(1) { })
  end
end
