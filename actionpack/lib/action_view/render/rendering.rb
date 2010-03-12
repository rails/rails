require 'active_support/core_ext/object/try'

module ActionView
  module Rendering
    # Returns the result of a render that's dictated by the options hash. The primary options are:
    #
    # * <tt>:partial</tt> - See ActionView::Partials.
    # * <tt>:update</tt> - Calls update_page with the block given.
    # * <tt>:file</tt> - Renders an explicit template file (this used to be the old default), add :locals to pass in those.
    # * <tt>:inline</tt> - Renders an inline template similar to how it's done in the controller.
    # * <tt>:text</tt> - Renders the text passed in out.
    #
    # If no options hash is passed or :update specified, the default is to render a partial and use the second parameter
    # as the locals hash.
    def render(options = {}, locals = {}, &block) #:nodoc:
      case options
      when Hash
        if block_given?
          content = _render_partial(options.merge(:partial => options[:layout]), &block)
          safe_concat(content)
        else
          _render(options)
        end
      when :update
        update_page(&block)
      else
        _render_partial(:partial => options, :locals => locals)
      end
    end

    # This is the API to render a ViewContext's template from a controller.
    def render_template(options, &block)
      _evaluate_assigns_and_ivars

      # TODO Layout for partials should be handled here, because inside the
      # partial renderer it looks for the layout as a partial.
      if options.key?(:partial) && options[:layout]
        options[:layout] = _find_layout(options[:layout])
      end

      _render(options, &block)
    end

    # This method holds the common render logic for both controllers and
    # views rendering stacks.
    def _render(options) #:nodoc:
      if options.key?(:partial)
        _render_partial(options)
      else
        template = _determine_template(options)
        yield template if block_given?
        _render_template(template, options[:layout], options)
      end
    end

    # Determine the template to be rendered using the given options.
    def _determine_template(options) #:nodoc:
      if options.key?(:inline)
        handler = Template.handler_class_for_extension(options[:type] || "erb")
        Template.new(options[:inline], "inline template", handler, {})
      elsif options.key?(:text)
        Template::Text.new(options[:text], self.formats.try(:first))
      elsif options.key?(:_template)
        options[:_template]
      elsif options.key?(:file)
        with_fallbacks { find(options[:file], options[:prefix]) }
      elsif options.key?(:template)
        find(options[:template], options[:prefix])
      end
    end

    # Renders the given template. An string representing the layout can be
    # supplied as well.
    def _render_template(template, layout = nil, options = {}) #:nodoc:
      locals = options[:locals] || {}
      layout = _find_layout(layout) if layout

      ActiveSupport::Notifications.instrument("action_view.render_template",
        :identifier => template.identifier, :layout => layout.try(:identifier)) do

        content = template.render(self, locals) { |*name| _layout_for(*name) }
        @_content_for[:layout] = content

        if layout
          @_layout = layout.identifier
          content  = _render_layout(layout, locals)
        end

        content
      end
    end

  end
end
