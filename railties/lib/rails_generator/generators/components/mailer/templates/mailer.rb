class <%= class_name %> < ActionMailer::Base
<% for action in actions -%>

  def <%= action %>(sent_on = Time.now)
    @subject    = '<%= class_name %>#<%= action %>'
    @body       = {}
    @recipients = ''
    @from       = ''
    @sent_on    = sent_on
    @headers    = {}
  end
<% end -%>
end
