module ActionController
  module Layouts
    def render_to_string(options)
      if !options.key?(:text) || options.key?(:layout)
        options[:_layout] = options.key?(:layout) ? _layout_for_option(options[:layout]) : _default_layout
      end
      
      super
    end
  end
end