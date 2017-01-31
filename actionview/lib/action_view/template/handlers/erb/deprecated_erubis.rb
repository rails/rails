::ActiveSupport::Deprecation.warn("ActionView::Template::Handlers::Erubis is deprecated and will be removed from Rails 5.2. Switch to ActionView::Template::Handlers::ERB::Erubi instead.")

module ActionView
  class Template
    module Handlers
      Erubis = ERB::Erubis
    end
  end
end
