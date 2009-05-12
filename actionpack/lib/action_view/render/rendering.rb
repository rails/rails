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
        original_content_for_layout = @content_for_layout if defined?(@content_for_layout)
        @content_for_layout = content

        @cached_content_for_layout = @content_for_layout
        _render_template(layout, locals)
      ensure
        @content_for_layout = original_content_for_layout
      end
    end

    def _render_template(template, local_assigns = {})
      with_template(template) do
        _evaluate_assigns_and_ivars
        _set_controller_content_type(template.mime_type) if template.respond_to?(:mime_type)

        template.render(self, local_assigns) do |*names|
          if !instance_variable_defined?(:"@content_for_#{names.first}") && 
          instance_variable_defined?(:@_proc_for_layout) && (proc = @_proc_for_layout)
            capture(*names, &proc)
          elsif instance_variable_defined?(ivar = :"@content_for_#{names.first || :layout}")
            instance_variable_get(ivar)
          end        
        end
      end
    rescue Exception => e
      if TemplateError === e
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
      if controller && logger
        logger.info("Rendering #{template.identifier}" + 
          (options[:status] ? " (#{options[:status]})" : ''))
      end
  
      content = if partial
        object = partial unless partial == true
        _render_partial_object(template, options, object)
      else
        _render_template(template, options[:locals] || {})
      end
  
      return content unless layout
      _render_content_with_layout(content, layout, options[:locals] || {})
    end
  end
end