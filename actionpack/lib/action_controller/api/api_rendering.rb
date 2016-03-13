module ActionController
  module ApiRendering
    extend ActiveSupport::Concern

    included do
      include Rendering
      include ActionView::Rendering
    end

    def render_to_body(options = {})
      _process_options(options)
      super
    end
  end
end
