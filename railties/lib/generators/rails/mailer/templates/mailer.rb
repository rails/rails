class <%= class_name %> < ActionMailer::Base
  delivers_from "mail@<%= application_name %>.com"
<% for action in actions -%>

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.actionmailer.<%= file_name %>.<%= action %>.subject
  #
  def <%= action %>
    @greeting = "Hi"
    mail(:to => "")
  end
<% end -%>
end