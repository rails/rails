require 'active_support/core_ext/object/try'
require 'active_support/core_ext/array/wrap'

module ActionView
  class TemplateRenderer < AbstractRenderer #:nodoc:
    def render(context, options)
      @view = context

      wrap_formats(options[:template] || options[:file]) do
        template = determine_template(options)
        freeze_formats(template.formats, true)
        render_template(template, options[:layout], options[:locals])
      end
    end

    # Determine the template to be rendered using the given options.
    def determine_template(options) #:nodoc:
      keys = options[:locals].try(:keys) || []

      if options.key?(:text)
        Template::Text.new(options[:text], formats.try(:first))
      elsif options.key?(:file)
        with_fallbacks { find_template(options[:file], nil, false, keys) }
      elsif options.key?(:inline)
        handler = Template.handler_for_extension(options[:type] || "erb")
        Template.new(options[:inline], "inline template", handler, :locals => keys)
      elsif options.key?(:template)
        options[:template].respond_to?(:render) ?
          options[:template] : find_template(options[:template], options[:prefixes], false, keys)
      end
    end

    # Renders the given template. An string representing the layout can be
    # supplied as well.
    def render_template(template, layout_name = nil, locals = {}) #:nodoc:
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
      begin
        with_layout_format do
          layout =~ /^\// ?
            with_fallbacks { find_template(layout, nil, false, keys) } : find_template(layout, nil, false, keys)
        end
      rescue ActionView::MissingTemplate
        update_details(:formats => nil) do
          raise unless template_exists?(layout)
        end
      end
    end
  end
end
