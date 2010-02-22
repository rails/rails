require 'test_helper'

class <%= class_name %>Test < ActionMailer::TestCase
<% for action in actions -%>
  test "<%= action %>" do
    @expected.subject = <%= action.to_s.humanize.inspect %>
    @expected.to      = "to@example.org"
    @expected.from    = "from@example.com"
    @expected.body    = read_fixture("<%= action %>")

    assert_equal @expected, <%= class_name %>.<%= action %>
  end

<% end -%>
<% if actions.blank? -%>
  # replace this with your real tests
  test "the truth" do
    assert true
  end
<% end -%>
end
