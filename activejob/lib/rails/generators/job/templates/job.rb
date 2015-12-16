<% module_namespacing do -%>
class <%= class_name %>Job < ApplicationJob
  queue_as :<%= options[:queue] %>

  def perform(*args)
    # Do something later
  end
end
<% end -%>
