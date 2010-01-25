require 'test_helper'

class <%= class_name %>Test < ActionMailer::TestCase
<% for action in actions -%>
  test "<%= action %>" do
    @actual = <%= class_name %>.<%= action %>

    @expected.subject = <%= action.to_s.humanize.inspect %>
    @expected.body    = read_fixture("<%= action %>")
    @expected.date    = Time.now

    assert_difference "<%= class_name %>.deliveries.size" do
      @actual.deliver
    end

    assert_equal @expected.encoded, @actual.encoded
  end

<% end -%>
<% if actions.blank? -%>
  # replace this with your real tests
  test "the truth" do
    assert true
  end
<% end -%>
end
