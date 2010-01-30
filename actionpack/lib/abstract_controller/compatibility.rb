module AbstractController
  module Compatibility
    extend ActiveSupport::Concern

    def _find_layout(name, details)
      details[:prefix] = nil if name =~ /\blayouts/
      super
    end

    # Move this into a "don't run in production" module
    def _default_layout(details, require_layout = false)
      super
    rescue ActionView::MissingTemplate
      _find_layout(_layout({}), {})
      nil
    end
  end
end
