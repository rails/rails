require File.dirname(__FILE__) + '<%= '/..' * class_nesting_depth %>/../test_helper'

class <%= class_name %>Test < ActionMailer::TestCase
  tests <%= class_name %>
<% for action in actions -%>
  def test_<%= action %>
    @expected.subject = '<%= class_name %>#<%= action %>'
    @expected.body    = read_fixture('<%= action %>')
    @expected.date    = Time.now

    assert_equal @expected.encoded, <%= class_name %>.create_<%= action %>(@expected.date).encoded
  end

<% end -%>
<% if actions.blank? -%>
  # replace this with your real tests
  def test_truth
    assert true
  end
<% end -%>
end
