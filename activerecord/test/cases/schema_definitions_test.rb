require "cases/helper"

class SchemaDefinitionsTest < ActiveRecord::TestCase

  REGRESSION_SAMPLES = %w{000249 125014 003912 256051 524287}

  test 'fast_string_to_time converts properly' do
    converted = ActiveRecord::ConnectionAdapters::Column.send('fast_string_to_time', "2010-01-12 12:34:56.000249")
    assert_equal Time.mktime(2010, 01, 12, 12, 34, 56, 249), converted
  end

  test 'fallback_string_to_time converts properly' do
    converted = ActiveRecord::ConnectionAdapters::Column.send('fallback_string_to_time', "2010-01-12 12:34:56.000249")
    assert_equal Time.mktime(2010, 01, 12, 12, 34, 56, 249), converted
  end

  test 'fallback_string_to_time converts properly with no microseconds' do
    converted = ActiveRecord::ConnectionAdapters::Column.send('fallback_string_to_time', "2010-01-12 12:34:56")
    assert_equal Time.mktime(2010, 01, 12, 12, 34, 56, 0), converted
  end

  test "fast_string_to_time can handle problematic microseconds" do
    REGRESSION_SAMPLES.each do |u|
      converted = ActiveRecord::ConnectionAdapters::Column.send('fast_string_to_time', "2010-01-12 12:34:56.#{u}")
      assert_equal u.to_i, converted.usec
    end
  end

  test "microseconds can handle problematic microseconds" do
    REGRESSION_SAMPLES.each do |u|
      i = u.to_i
      converted = ActiveRecord::ConnectionAdapters::Column.send('microseconds', {:sec_fraction => Rational(i, 1_000_000)})
      assert_equal i, converted

      converted = ActiveRecord::ConnectionAdapters::Column.send('microseconds', {:sec_fraction => Rational(i, 1_000_000)})
      assert_equal i, converted
    end
  end

  test 'fast constant is equally restrictive' do
    assert_match ActiveRecord::ConnectionAdapters::Column::Format::NEW_ISO_DATETIME, "2010-01-12 12:34:56.555493"
  end
end
