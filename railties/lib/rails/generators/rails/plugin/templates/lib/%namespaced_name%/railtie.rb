<%= wrap_in_modules <<-rb.strip_heredoc
  class Railtie < ::Rails::Railtie
  end
rb
%>
