require 'test_helper'

class <%= class_name %>Test < ActionMailer::TestCase
<% for action in actions -%>
  test "<%= action %>" do
    @expected.subject = '<%= class_name %>#<%= action %>'
    @expected.body    = read_fixture('<%= action %>')
    @expected.date    = Time.now

    assert_equal @expected.encoded, <%= class_name %>.create_<%= action %>(@expected.date).encoded
  end

<% end -%>
<% if actions.blank? -%>
  # replace this with your real tests
  test "the truth" do
    assert true
  end
<% end -%>
end
