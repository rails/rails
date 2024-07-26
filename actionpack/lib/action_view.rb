require 'action_view/erb_template'
# require 'action_view/eruby_template'

# Include all helpers in template class
template_helpers_dir = File.dirname(__FILE__) + "/action_view/helpers/"
Dir.foreach(template_helpers_dir) do |helper_file| 
  next unless helper_file =~ /_helper.rb$/
  require template_helpers_dir + helper_file
  helper_module_name = helper_file.capitalize.gsub(/_([a-z])/) { |m| $1.capitalize }[0..-4]

  if ActionView::Helpers.const_defined?(helper_module_name)
    ActionView::ERbTemplate.class_eval("include ActionView::Helpers::#{helper_module_name}") 
  end
end