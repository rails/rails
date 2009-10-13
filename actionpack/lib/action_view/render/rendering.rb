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
        layout = options[:layout]
        options[:locals] ||= {}

        if block_given?
          return concat(_render_partial(options.merge(:partial => layout), &block))
        elsif options.key?(:partial)
          return _render_partial(options)
        end

        layout = find(layout, {:formats => formats}) if layout

        if file = options[:file]
          template = find(file, {:formats => formats})
          _render_template(template, layout, :locals => options[:locals])
        elsif inline = options[:inline]
          _render_inline(inline, layout, options)
        elsif text = options[:text]
          _render_text(text, layout, options[:locals])
        end
      when :update
        update_page(&block)
      else
        _render_partial(:partial => options, :locals => locals)
      end
    end

    # You can think of a layout as a method that is called with a block. _layout_for
    # returns the contents that are yielded to the layout. If the user calls yield
    # :some_name, the block, by default, returns content_for(:some_name). If the user
    # calls yield, the default block returns content_for(:layout).
    #
    # The user can override this default by passing a block to the layout.
    #
    # ==== Example
    #
    #   # The template
    #   <% render :layout => "my_layout" do %>Content<% end %>
    #
    #   # The layout
    #   <html><% yield %></html>
    #
    # In this case, instead of the default block, which would return content_for(:layout),
    # this method returns the block that was passed in to render layout, and the response
    # would be <html>Content</html>.
    #
    # Finally, the block can take block arguments, which can be passed in by yield.
    #
    # ==== Example
    #
    #   # The template
    #   <% render :layout => "my_layout" do |customer| %>Hello <%= customer.name %><% end %>
    #
    #   # The layout
    #   <html><% yield Struct.new(:name).new("David") %></html>
    #
    # In this case, the layout would receive the block passed into <tt>render :layout</tt>,
    # and the Struct specified in the layout would be passed into the block. The result
    # would be <html>Hello David</html>.
    def _layout_for(name = nil)
      return @_content_for[name || :layout] if !block_given? || name

      with_output_buffer do
        return yield
      end
    end

    def _render_inline(inline, layout, options)
      handler = Template.handler_class_for_extension(options[:type] || "erb")
      template = Template.new(options[:inline],
        "inline #{options[:inline].inspect}", handler, {})

      locals = options[:locals]
      content = template.render(self, locals)
      _render_text(content, layout, locals)
    end

    def _render_text(content, layout, locals)
      content = layout.render(self, locals) do |*name|
        _layout_for(*name) { content }
      end if layout
      content
    end

    # This is the API to render a ViewContext's template from a controller.
    #
    # Internal Options:
    # _template:: The Template object to render
    # _layout::   The layout, if any, to wrap the Template in
    # _partial::  true if the template is a partial
    def render_template(options)
      _evaluate_assigns_and_ivars
      template, layout, partial = options.values_at(:_template, :_layout, :_partial)
      _render_template(template, layout, options, partial)
    end

    def _render_template(template, layout = nil, options = {}, partial = nil)
      logger && logger.info do
        msg = "Rendering #{template.inspect}"
        msg << " (#{options[:status]})" if options[:status]
        msg
      end

      locals = options[:locals] || {}

      content = if partial
        _render_partial_object(template, options)
      else
        template.render(self, locals)
      end

      @cached_content_for_layout = content
      @_content_for[:layout] = content

      if layout
        @_layout = layout.identifier
        logger.info("Rendering template within #{layout.inspect}") if logger
        content = layout.render(self, locals) {|*name| _layout_for(*name) }
      end
      content
    end
  end
end