require 'abstract_unit'
require 'action_view/partial_iteration'
class PartialIterationTest < ActiveSupport::TestCase

  def test_has_size_and_index
    iteration = ActionView::PartialIteration.new 3, 0
    assert_equal 0, iteration.index, "should be at the first index"
    assert_equal 3, iteration.size, "should have the size"
  end

  def test_first_is_true_when_current_is_at_the_first_index
    iteration = ActionView::PartialIteration.new 3, 0
    assert iteration.first?, "first when current is 0"
  end

  def test_first_is_false_unless_current_is_at_the_first_index
    iteration = ActionView::PartialIteration.new 3, 1
    assert !iteration.first?, "not first when current is 1"
  end

  def test_last_is_true_when_current_is_at_the_last_index
    iteration = ActionView::PartialIteration.new 3, 2
    assert iteration.last?, "last when current is 2"
  end

  def test_last_is_false_unless_current_is_at_the_last_index
    iteration = ActionView::PartialIteration.new 3, 0
    assert !iteration.last?, "not last when current is 0"
  end

end
