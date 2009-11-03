require "cases/helper"

class TimeWithZoneTest < ActiveRecord::TestCase

  def setup
    @column = ActiveRecord::ConnectionAdapters::Column.new('created_at', 0, 'datetime')
    @time_with_zone = ActiveRecord::Type::TimeWithZone.new(@column)
  end

  test "typecast" do
    Time.use_zone("Pacific Time (US & Canada)") do
      time_string = "2009-10-07 21:29:10"
      time = Time.zone.parse(time_string)

      # assert_equal time, @time_with_zone.cast(time_string)
      assert_equal nil, @time_with_zone.cast('')
      assert_equal nil, @time_with_zone.cast(nil)

      assert_equal time, @time_with_zone.precast(time)
      assert_equal time, @time_with_zone.precast(time_string)
      assert_equal time, @time_with_zone.precast(time.to_time)
      # assert_equal "#{time.to_date.to_s} 00:00:00 -0700", @time_with_zone.precast(time.to_date).to_s
    end
  end

  test "cast as boolean" do
    Time.use_zone('Central Time (US & Canada)') do
      time = Time.zone.now

      assert_equal true, @time_with_zone.boolean(time)
      assert_equal true, @time_with_zone.boolean(time.to_date)
      assert_equal true, @time_with_zone.boolean(time.to_time)

      assert_equal true, @time_with_zone.boolean(time.to_s)
      assert_equal true, @time_with_zone.boolean(time.to_date.to_s)
      assert_equal true, @time_with_zone.boolean(time.to_time.to_s)

      assert_equal false, @time_with_zone.boolean('')
    end
  end

end
