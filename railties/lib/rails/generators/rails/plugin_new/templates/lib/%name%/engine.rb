module <%= camelized %>
  class Engine < ::Rails::Engine
<% if mountable? -%>
    isolate_namespace <%= camelized %>
<% end -%>
  end
end
