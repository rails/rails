require 'cases/helper'
require 'models/topic'

class InvalidDateTest < ActiveRecord::TestCase
  def test_assign_valid_dates
    valid_dates = [[2007, 11, 30], [1993, 2, 28], [2008, 2, 29]]

    invalid_dates = [[2007, 11, 31], [1993, 2, 29], [2007, 2, 29]]

    valid_dates.each do |date_src|
      topic = Topic.new("last_read(1i)" => date_src[0].to_s, "last_read(2i)" => date_src[1].to_s, "last_read(3i)" => date_src[2].to_s)
      # Oracle DATE columns are datetime columns and Oracle adapter returns Time value
      if current_adapter?(:OracleAdapter)
        assert_equal(topic.last_read.to_date, Date.new(*date_src))
      else
        assert_equal(topic.last_read, Date.new(*date_src))
      end
    end

    invalid_dates.each do |date_src|
      assert_nothing_raised do
        topic = Topic.new({"last_read(1i)" => date_src[0].to_s, "last_read(2i)" => date_src[1].to_s, "last_read(3i)" => date_src[2].to_s})
        # Oracle DATE columns are datetime columns and Oracle adapter returns Time value
        if current_adapter?(:OracleAdapter)
          assert_equal(topic.last_read.to_date, Time.local(*date_src).to_date, "The date should be modified according to the behavior of the Time object")
        else
          assert_equal(topic.last_read, Time.local(*date_src).to_date, "The date should be modified according to the behavior of the Time object")
        end
      end
    end
  end
end
