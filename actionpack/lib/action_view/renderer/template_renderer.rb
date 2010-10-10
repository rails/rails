require 'action_view/renderer/abstract_renderer'

module ActionView
  class TemplateRenderer < AbstractRenderer #:nodoc:
    def render(options)
      wrap_formats(options[:template] || options[:file]) do
        template = determine_template(options)
        lookup_context.freeze_formats(template.formats, true)
        render_template(template, options[:layout], options)
      end
    end

    # Determine the template to be rendered using the given options.
    def determine_template(options) #:nodoc:
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
    def render_template(template, layout = nil, options = {}) #:nodoc:
      view, locals = @view, options[:locals] || {}
      layout = find_layout(layout, locals.keys) if layout

      ActiveSupport::Notifications.instrument("render_template.action_view",
        :identifier => template.identifier, :layout => layout.try(:virtual_path)) do

        content = template.render(view, locals) { |*name| view._layout_for(*name) }
      
        if layout
          view.store_content_for(:layout, content)
          content = render_layout(layout, locals)
        end

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
      rescue ActionView::MissingTemplate => e
        update_details(:formats => nil) do
          raise unless template_exists?(layout)
        end
      end
    end
  end
end