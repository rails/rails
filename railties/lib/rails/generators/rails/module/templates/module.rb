<% module_namespacing do -%>
module <%= class_name %>
<% actions.each do |action| -%>
  <% actions.each do |action| -%>
    def <%= action %>
    end
  <%= "\n" unless action == actions.last -%>
  <% end -%>
<% end -%>
end
<% end -%>
