require 'active_support/core_ext/object/try'

module ActionView
  # = Action View Rendering
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
    def render(options = {}, locals = {}, &block)
      case options
      when Hash
        if block_given?
          _render_partial(options.merge(:partial => options[:layout]), &block)
        elsif options.key?(:partial)
          _render_partial(options)
        else
          _wrap_formats(options[:template] || options[:file]) do
            template = _determine_template(options)
            lookup_context.freeze_formats(template.formats, true)
            _render_template(template, options[:layout], options)
          end
        end
      when :update
        update_page(&block)
      else
        _render_partial(:partial => options, :locals => locals)
      end
    end

    # Checks if the given path contains a format and if so, change
    # the lookup context to take this new format into account.
    def _wrap_formats(value)
      return yield unless value.is_a?(String)
      @@formats_regexp ||= /\.(#{Mime::SET.symbols.join('|')})$/

      if value.sub!(@@formats_regexp, "")
        update_details(:formats => [$1.to_sym]){ yield }
      else
        yield
      end
    end

    # Determine the template to be rendered using the given options.
    def _determine_template(options) #:nodoc:
      keys = (options[:locals] ||= {}).keys

      if options.key?(:inline)
        handler = Template.handler_class_for_extension(options[:type] || "erb")
        Template.new(options[:inline], "inline template", handler, { :locals => keys })
      elsif options.key?(:text)
        Template::Text.new(options[:text], formats.try(:first))
      elsif options.key?(:file)
        with_fallbacks { find_template(options[:file], options[:prefix], false, keys) }
      elsif options.key?(:template)
        options[:template].respond_to?(:render) ?
          options[:template] : find_template(options[:template], options[:prefix], false, keys)
      end
    end

    # Renders the given template. An string representing the layout can be
    # supplied as well.
    def _render_template(template, layout = nil, options = {}) #:nodoc:
      locals = options[:locals] || {}
      layout = find_layout(layout, locals.keys) if layout

      ActiveSupport::Notifications.instrument("render_template.action_view",
        :identifier => template.identifier, :layout => layout.try(:virtual_path)) do

        content = template.render(self, locals) { |*name| _layout_for(*name) }
        @_content_for[:layout] = content if layout

        content = _render_layout(layout, locals) if layout
        content
      end
    end
  end
end
