<% module_namespacing do -%>
class <%= class_name %>Job < ActiveJob::Base
  queue_as :<%= options[:queue] %>

  def perform(*args)
    # Do something later
  end
end
<% end -%>
