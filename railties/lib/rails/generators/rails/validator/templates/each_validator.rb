<% module_namespacing do -%>
class <%= class_name %>Validator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
  end
end
<% end -%>
