require "cases/helper"
require "models/topic"
require "models/task"

class DateTimeTest < ActiveRecord::TestCase
  include InTimeZone

  def test_saves_both_date_and_time
    with_env_tz "America/New_York" do
      with_timezone_config default: :utc do
        time_values = [1807, 2, 10, 15, 30, 45]
        # create DateTime value with local time zone offset
        local_offset = Rational(Time.local(*time_values).utc_offset, 86400)
        now = DateTime.civil(*(time_values + [local_offset]))

        task = Task.new
        task.starting = now
        task.save!

        # check against Time.local, since some platforms will return a Time instead of a DateTime
        assert_equal Time.local(*time_values), Task.find(task.id).starting
      end
    end
  end

  def test_assign_empty_date_time
    task = Task.new
    task.starting = ""
    task.ending = nil
    assert_nil task.starting
    assert_nil task.ending
  end

  def test_assign_bad_date_time_with_timezone
    in_time_zone "Pacific Time (US & Canada)" do
      task = Task.new
      task.starting = "2014-07-01T24:59:59GMT"
      assert_nil task.starting
    end
  end

  def test_assign_empty_date
    topic = Topic.new
    topic.last_read = ""
    assert_nil topic.last_read
  end

  def test_assign_empty_time
    topic = Topic.new
    topic.bonus_time = ""
    assert_nil topic.bonus_time
  end

  def test_assign_in_local_timezone
    now = DateTime.civil(2017, 3, 1, 12, 0, 0)
    with_timezone_config default: :local do
      task = Task.new starting: now
      assert_equal now, task.starting
    end
  end
end
