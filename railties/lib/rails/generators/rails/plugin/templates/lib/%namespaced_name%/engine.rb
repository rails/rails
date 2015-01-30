<%= wrap_in_modules <<-rb.strip_heredoc
  class Engine < ::Rails::Engine
  #{mountable? ? '  isolate_namespace ' + modules.first : ' '}
  end
rb
%>
