require File.dirname(__FILE__) + '/../test_helper'

class <%= class_name %>Test < Test::Unit::TestCase
  fixtures :<%= table_name %>

  def setup
    @<%= singular_name %> = <%= class_name %>.find(1)
  end

  # Replace this with your real tests.
  def test_truth
    assert_kind_of <%= class_name %>,  @<%= singular_name %>
  end
end
