class <%= class_name %> < ActiveRecord::Base
<% attributes.select { |a| a.type.to_s == 'references' }.each do |attribute| -%>
  belongs_to :<%= attribute.name %>
<% end -%>
end
