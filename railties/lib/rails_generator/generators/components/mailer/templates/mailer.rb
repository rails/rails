class <%= class_name %> < ActionMailer::Base
  
  # change to your domain name
  default_url_options[:host] = 'example.com'
<% for action in actions -%>

  def <%= action %>(sent_at = Time.now)
    subject    '<%= class_name %>#<%= action %>'
    recipients ''
    from       ''
    sent_on    sent_at
    
    body       :greeting => 'Hi,'
  end
<% end -%>

end
