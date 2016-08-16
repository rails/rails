require 'cases/helper'
require 'models/invoice'
require 'models/line_item'
require 'models/topic'
require 'models/node'
require 'models/tree'

class TouchLaterTest < ActiveRecord::TestCase
  fixtures :nodes, :trees

  def test_touch_laster_raise_if_non_persisted
    invoice = Invoice.new
    Invoice.transaction do
      assert_not invoice.persisted?
      assert_raises(ActiveRecord::ActiveRecordError) do
        invoice.touch_later
      end
    end
  end

  def test_touch_later_dont_set_dirty_attributes
    invoice = Invoice.create!
    invoice.touch_later
    assert_not invoice.changed?
  end

  def test_touch_later_respects_no_touching_policy
    time = Time.now.utc - 25.days
    topic = Topic.create!(updated_at: time, created_at: time)
    Topic.no_touching do
      topic.touch_later
    end
    assert_equal time.to_i, topic.updated_at.to_i
  end

  def test_touch_later_update_the_attributes
    time = Time.now.utc - 25.days
    topic = Topic.create!(updated_at: time, created_at: time)
    assert_equal time.to_i, topic.updated_at.to_i
    assert_equal time.to_i, topic.created_at.to_i

    Topic.transaction do
      topic.touch_later(:created_at)
      assert_not_equal time.to_i, topic.updated_at.to_i
      assert_not_equal time.to_i, topic.created_at.to_i

      assert_equal time.to_i, topic.reload.updated_at.to_i
      assert_equal time.to_i, topic.reload.created_at.to_i
    end
    assert_not_equal time.to_i, topic.reload.updated_at.to_i
    assert_not_equal time.to_i, topic.reload.created_at.to_i
  end

  def test_touch_touches_immediately
    time = Time.now.utc - 25.days
    topic = Topic.create!(updated_at: time, created_at: time)
    assert_equal time.to_i, topic.updated_at.to_i
    assert_equal time.to_i, topic.created_at.to_i

    Topic.transaction do
      topic.touch_later(:created_at)
      topic.touch

      assert_not_equal time, topic.reload.updated_at
      assert_not_equal time, topic.reload.created_at
    end
  end

  def test_touch_later_an_association_dont_autosave_parent
    time = Time.now.utc - 25.days
    line_item = LineItem.create!(amount: 1)
    invoice = Invoice.create!(line_items: [line_item])
    invoice.touch(time: time)

    Invoice.transaction do
      line_item.update(amount: 2)
      assert_equal time.to_i, invoice.reload.updated_at.to_i
    end

    assert_not_equal time.to_i, invoice.updated_at.to_i
  end

  def test_touch_touches_immediately_with_a_custom_time
    time = (Time.now.utc - 25.days).change(nsec: 0)
    topic = Topic.create!(updated_at: time, created_at: time)
    assert_equal time, topic.updated_at
    assert_equal time, topic.created_at

    Topic.transaction do
      topic.touch_later(:created_at)
      time = Time.now.utc - 2.days
      topic.touch(time: time)

      assert_equal time.to_i, topic.reload.updated_at.to_i
      assert_equal time.to_i, topic.reload.created_at.to_i
    end
  end

  def test_touch_later_dont_hit_the_db
    invoice = Invoice.create!
    assert_queries(0) do
      invoice.touch_later
    end
  end

  def test_touching_three_deep
    previous_tree_updated_at        = trees(:root).updated_at
    previous_grandparent_updated_at = nodes(:grandparent).updated_at
    previous_parent_updated_at      = nodes(:parent_a).updated_at
    previous_child_updated_at       = nodes(:child_one_of_a).updated_at

    travel 5.seconds do
      Node.create! parent: nodes(:child_one_of_a), tree: trees(:root)
    end

    assert_not_equal nodes(:child_one_of_a).reload.updated_at, previous_child_updated_at
    assert_not_equal nodes(:parent_a).reload.updated_at, previous_parent_updated_at
    assert_not_equal nodes(:grandparent).reload.updated_at, previous_grandparent_updated_at
    assert_not_equal trees(:root).reload.updated_at, previous_tree_updated_at
  end
end
