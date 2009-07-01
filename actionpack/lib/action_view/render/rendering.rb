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
    def render(options = {}, local_assigns = {}, &block) #:nodoc:
      local_assigns ||= {}

      @exempt_from_layout = true

      case options
      when Hash
        options[:locals] ||= {}
        layout = options[:layout]
            
        return _render_partial_with_layout(layout, options) if options.key?(:partial)
        return _render_partial_with_block(layout, block, options) if block_given?
    
        layout = find_by_parts(layout, {:formats => formats}) if layout
    
        if file = options[:file]
          template = find_by_parts(file, {:formats => formats})
          _render_template_with_layout(template, layout, :locals => options[:locals])
        elsif inline = options[:inline]
          _render_inline(inline, layout, options)
        elsif text = options[:text]
          _render_text(text, layout, options)
        end
      when :update
        update_page(&block)
      when String, NilClass
        _render_partial(:partial => options, :locals => local_assigns)
      end
    end
    
    def _render_content_with_layout(content, layout, locals)
      return content unless layout
  
      locals ||= {}

      if controller && layout
        @_layout = layout.identifier
        logger.info("Rendering template within #{layout.identifier}") if logger
      end
  
      begin
        old_content, @_content_for[:layout] = @_content_for[:layout], content

        @cached_content_for_layout = @_content_for[:layout]
        _render_template(layout, locals)
      ensure
        @_content_for[:layout] = old_content
      end
    end

    # You can think of a layout as a method that is called with a block. This method
    # returns the block that the layout is called with. If the user calls yield :some_name,
    # the block, by default, returns content_for(:some_name). If the user calls yield,
    # the default block returns content_for(:layout).
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
    def layout_proc(name)
      @_default_layout ||= proc { |*names| @_content_for[names.first || :layout] }
      !@_content_for.key?(name) && @_proc_for_layout || @_default_layout
    end

    def _render_template(template, local_assigns = {})
      with_template(template) do
        template.render(self, local_assigns) do |*names|
          capture(*names, &layout_proc(names.first))
        end
      end
    rescue Exception => e
      if e.is_a?(TemplateError)
        e.sub_template_of(template)
        raise e
      else
        raise TemplateError.new(template, assigns, e)
      end
    end

    def _render_inline(inline, layout, options)
      handler = Template.handler_class_for_extension(options[:type] || "erb")
      template = Template.new(options[:inline], "inline #{options[:inline].inspect}", handler, {})
      content = _render_template(template, options[:locals] || {})
      layout ? _render_content_with_layout(content, layout, options[:locals]) : content
    end

    def _render_text(text, layout, options)
      layout ? _render_content_with_layout(text, layout, options[:locals]) : text
    end

    def _render_template_from_controller(*args)
      @assigns_added = nil
      _render_template_with_layout(*args)
    end

    def _render_template_with_layout(template, layout = nil, options = {}, partial = false)
      logger && logger.info("Rendering #{template.identifier}#{' (#{options[:status]})' if options[:status]}")

      locals = options[:locals] || {}

      content = if partial
        object = partial unless partial == true
        _render_partial_object(template, options, object)
      else
        _render_template(template, locals)
      end
  
      layout ? _render_content_with_layout(content, layout, locals) : content
    end
  end
end