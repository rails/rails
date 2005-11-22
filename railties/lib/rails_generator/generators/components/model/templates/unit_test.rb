require File.dirname(__FILE__) + '<%= '/..' * class_nesting_depth %>/../test_helper'

class <%= class_name %>Test < Test::Unit::TestCase
  fixtures :<%= table_name %>

  # Replace this with your real tests.
  def test_truth
    assert_kind_of <%= class_name %>, <%= table_name %>(:first)
  end
end
