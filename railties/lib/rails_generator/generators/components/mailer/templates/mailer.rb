class <%= class_name %> < ActionMailer::Base
<% for action in actions -%>

  def <%= action %>(sent_at = Time.now)
    @subject    = '<%= class_name %>#<%= action %>'
    @body       = {}
    @recipients = ''
    @from       = ''
    @sent_on    = sent_at
    @headers    = {}
  end
<% end -%>
end
