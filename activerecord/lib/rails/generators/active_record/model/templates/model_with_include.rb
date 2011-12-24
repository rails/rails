<% module_namespacing do -%>
class <%= class_name %>
  include ActiveRecord::Model

<% attributes.select {|attr| attr.reference? }.each do |attribute| -%>
  belongs_to :<%= attribute.name %>
<% end -%>
end
<% end -%>
