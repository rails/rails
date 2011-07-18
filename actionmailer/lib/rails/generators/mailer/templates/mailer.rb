<% module_namespacing do -%>
class <%= class_name %> < ActionMailer::Base
  default <%= key_value :from, '"from@example.com"' %>
<% actions.each do |action| -%>

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.<%= file_path.gsub("/",".") %>.<%= action %>.subject
  #
  def <%= action %>
    @greeting = "Hi"

    mail <%= key_value :to, '"to@example.org"' %>
  end
<% end -%>
end
<% end -%>
