require 'abstract_unit'
require 'fixtures/topic'
require 'fixtures/task'

class DateTimeTest < Test::Unit::TestCase
  def test_saves_both_date_and_time
    now = 200.years.ago.to_datetime

    task = Task.new
    task.starting = now
    task.save!

    assert_equal now, Task.find(task.id).starting
  end

  def test_assign_empty_date_time
    task = Task.new
    task.starting = ''
    task.ending = nil
    assert_nil task.starting
    assert_nil task.ending
  end

  def test_assign_empty_date
    topic = Topic.new
    topic.last_read = ''
    assert_nil topic.last_read
  end

  def test_assign_empty_time
    topic = Topic.new
    topic.bonus_time = ''
    assert_nil topic.bonus_time
  end
end
