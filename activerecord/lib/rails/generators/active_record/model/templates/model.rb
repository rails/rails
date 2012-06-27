<% module_namespacing do -%>
class <%= class_name %> < <%= parent_class_name.classify %>
<% attributes.select {|attr| attr.reference? }.each do |attribute| -%>
  belongs_to :<%= attribute.name %><%= ', polymorphic: true' if attribute.polymorphic? %>
<% end -%>
<% if !accessible_attributes.empty? -%>
  attr_accessible <%= accessible_attributes.map {|a| ":#{a.name}" }.sort.join(', ') %>
<% else -%>
  # attr_accessible :title, :body
<% end -%>
end
<% end -%>
