<% module_namespacing do -%>
class <%= class_name %>Preview < ActionMailer::Preview
<% actions.each do |action| -%>

  def <%= action %>
    <%= class_name %>.<%= action %>
  end
<% end -%>

end
<% end -%>
