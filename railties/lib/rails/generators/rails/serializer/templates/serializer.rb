<% module_namespacing do -%>
class <%= class_name %>Serializer < <%= parent_class_name %>
<% if attributes.any? -%>  attributes <%= attributes_names.map(&:inspect).join(", ") %>
<% end -%>
<% association_names.each do |attribute| -%>
  has_one :<%= attribute %>
<% end -%>
end
<% end -%>