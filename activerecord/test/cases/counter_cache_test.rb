require 'cases/helper'
require 'models/topic'
require 'models/reply'
require 'models/category'
require 'models/categorization'

class CounterCacheTest < ActiveRecord::TestCase
  fixtures :topics, :categories, :categorizations

  test "increment counter" do
    topic = Topic.find(1)
    assert_difference 'topic.reload.replies_count' do
      Topic.increment_counter(:replies_count, topic.id)
    end
  end

  test "decrement counter" do
    topic = Topic.find(1)
    assert_difference 'topic.reload.replies_count', -1 do
      Topic.decrement_counter(:replies_count, topic.id)
    end
  end

  test "reset counters" do
    topic = Topic.find(1)
    # throw the count off by 1
    Topic.increment_counter(:replies_count, topic.id)

    # check that it gets reset
    assert_difference 'topic.reload.replies_count', -1 do
      Topic.reset_counters(topic.id, :replies)
    end
  end

  test "update counter with initial null value" do
    category = categories(:general)
    assert_equal 2, category.categorizations.count
    assert_nil category.categorizations_count

    Category.update_counters(category.id, :categorizations_count => category.categorizations.count)
    assert_equal 2, category.reload.categorizations_count
  end

  test "update counter for decrement" do
    topic = Topic.find(1)
    assert_difference 'topic.reload.replies_count', -3 do
      Topic.update_counters(topic.id, :replies_count => -3)
    end
  end

  test "update counters of multiple records" do
    t1, t2 = topics(:first, :second)

    assert_difference ['t1.reload.replies_count', 't2.reload.replies_count'], 2 do
      Topic.update_counters([t1.id, t2.id], :replies_count => 2)
    end
  end
end
