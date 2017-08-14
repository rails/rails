# frozen_string_literal: true

<%= wrap_in_modules <<-rb.strip_heredoc
  class Railtie < ::Rails::Railtie
  end
rb
%>
