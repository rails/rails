require 'active_support/core_ext/object/try'

module ActionView
  class TemplateRenderer < AbstractRenderer #:nodoc:
    def render(context, options)
      @view    = context
      @details = extract_details(options)
      template = determine_template(options)

      prepend_formats(template.formats)

      @lookup_context.rendered_format ||= (template.formats.first || formats.first)

      render_template(template, options[:layout], options[:locals])
    end

    private

    # Determine the template to be rendered using the given options.
    def determine_template(options)
      keys = options.has_key?(:locals) ? options[:locals].keys : []

      if options.key?(:body)
        Template::Text.new(options[:body])
      elsif options.key?(:text)
        Template::Text.new(options[:text], formats.first)
      elsif options.key?(:plain)
        Template::Text.new(options[:plain])
      elsif options.key?(:html)
        Template::HTML.new(options[:html], formats.first)
      elsif options.key?(:file)
        with_fallbacks { find_file(options[:file], nil, false, keys, @details) }
      elsif options.key?(:inline)
        handler = Template.handler_for_extension(options[:type] || "erb")
        Template.new(options[:inline], "inline template", handler, :locals => keys)
      elsif options.key?(:template)
        if options[:template].respond_to?(:render)
          options[:template]
        else
          find_template(options[:template], options[:prefixes], false, keys, @details)
        end
      else
        raise ArgumentError, "You invoked render but did not give any of :partial, :template, :inline, :file, :plain, :text or :body option."
      end
    end

    # Renders the given template. A string representing the layout can be
    # supplied as well.
    def render_template(template, layout_name = nil, locals = nil) #:nodoc:
      view, locals = @view, locals || {}

      render_with_layout(layout_name, locals) do |layout|
        instrument(:template, :identifier => template.identifier, :layout => layout.try(:virtual_path)) do
          template.render(view, locals) { |*name| view._layout_for(*name) }
        end
      end
    end

    def render_with_layout(path, locals) #:nodoc:
      layout  = path && find_layout(path, locals.keys)
      content = yield(layout)

      if layout
        view = @view
        view.view_flow.set(:layout, content)
        layout.render(view, locals){ |*name| view._layout_for(*name) }
      else
        content
      end
    end

    # This is the method which actually finds the layout using details in the lookup
    # context object. If no layout is found, it checks if at least a layout with
    # the given name exists across all details before raising the error.
    def find_layout(layout, keys)
      with_layout_format { resolve_layout(layout, keys) }
    end

    def resolve_layout(layout, keys)
      case layout
      when String
        begin
          if layout =~ /^\//
            with_fallbacks { find_template(layout, nil, false, keys, @details) }
          else
            find_template(layout, nil, false, keys, @details)
          end
        rescue ActionView::MissingTemplate
          all_details = @details.merge(:formats => @lookup_context.default_formats)
          raise unless template_exists?(layout, nil, false, keys, all_details)
        end
      when Proc
        resolve_layout(layout.call, keys)
      when FalseClass
        nil
      else
        layout
      end
    end
  end
end
