<% module_namespacing do -%>
module <%= class_path.map(&:camelize).join('::') %>
  def self.table_name_prefix
    '<%= namespaced? ? namespaced_class_path.join('_') : class_path.join('_') %>_'
  end
end
<% end -%>
