require File.dirname(__FILE__) + '/../test_helper'

class <%= class_name %>Test < Test::Unit::TestCase
  fixtures :<%= table_name %>

  def setup
    $base_id = 1000001
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
