<% module_namespacing do -%>
module <%= class_path.map(&:camelize).join('::') %>
end
<% end -%>
