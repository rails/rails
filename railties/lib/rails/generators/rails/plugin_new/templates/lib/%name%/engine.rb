module <%= camelized %>
  class Engine < ::Rails::Engine
<% if mountable? -%>
    isolate_namespace <%= camelized %>
<% end -%>

  # Tie your engine into Rails.application.config
  config.<%= underscored %> = <%= camelized %>
  end
end
