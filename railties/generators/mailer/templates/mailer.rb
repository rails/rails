require 'action_mailer'

class <%= class_name %> < ActionMailer::Base
<% for action in actions -%>

  def <%= action %>(sent_on = Time.now)
    @recipients = ''
    @from       = ''
    @subject    = ''
    @body       = {}
    @sent_on    = sent_on
  end
<% end -%>
end
