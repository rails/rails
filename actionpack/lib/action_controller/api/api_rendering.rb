# frozen_string_literal: true

# :markup: markdown

module ActionController
  module ApiRendering
    extend ActiveSupport::Concern

    included do
      include Rendering
    end

    def render_to_body(options = {})
      _process_options(options)
      super
    end
  end
end
