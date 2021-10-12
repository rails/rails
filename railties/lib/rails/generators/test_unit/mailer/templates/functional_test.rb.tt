require "test_helper"

<% module_namespacing do -%>
class <%= class_name %>MailerTest < ActionMailer::TestCase
<% actions.each do |action| -%>
  test "<%= action %>" do
    mail = <%= class_name %>Mailer.<%= action %>
    assert_equal <%= action.to_s.humanize.inspect %>, mail.subject
    assert_equal ["to@example.org"], mail.to
    assert_equal ["from@example.com"], mail.from
    assert_match "Hi", mail.body.encoded
  end

<% end -%>
<% if actions.blank? -%>
  # test "the truth" do
  #   assert true
  # end
<% end -%>
end
<% end -%>
