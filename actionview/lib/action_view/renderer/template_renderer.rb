# frozen_string_literal: true

module ActionView
  class TemplateRenderer < AbstractRenderer #:nodoc:
    def render(context, options)
      @details = extract_details(options)
      template = determine_template(options)

      prepend_formats(template.format)

      render_template(context, template, options[:layout], options[:locals] || {})
    end

    private
      # Determine the template to be rendered using the given options.
      def determine_template(options)
        keys = options.has_key?(:locals) ? options[:locals].keys : []

        if options.key?(:body)
          Template::Text.new(options[:body])
        elsif options.key?(:plain)
          Template::Text.new(options[:plain])
        elsif options.key?(:html)
          Template::HTML.new(options[:html], formats.first)
        elsif options.key?(:file)
          if File.exist?(options[:file])
            Template::RawFile.new(options[:file])
          else
            raise ArgumentError, "`render file:` should be given the absolute path to a file. '#{options[:file]}' was given instead"
          end
        elsif options.key?(:inline)
          handler = Template.handler_for_extension(options[:type] || "erb")
          format = if handler.respond_to?(:default_format)
            handler.default_format
          else
            @lookup_context.formats.first
          end
          Template::Inline.new(options[:inline], "inline template", handler, locals: keys, format: format)
        elsif options.key?(:renderable)
          Template::Renderable.new(options[:renderable])
        elsif options.key?(:template)
          if options[:template].respond_to?(:render)
            options[:template]
          else
            @lookup_context.find_template(options[:template], options[:prefixes], false, keys, @details)
          end
        else
          raise ArgumentError, "You invoked render but did not give any of :partial, :template, :inline, :file, :plain, :html or :body option."
        end
      end

      # Renders the given template. A string representing the layout can be
      # supplied as well.
      def render_template(view, template, layout_name, locals)
        render_with_layout(view, template, layout_name, locals) do |layout|
          ActiveSupport::Notifications.instrument(
            "render_template.action_view",
            identifier: template.identifier,
            layout: layout && layout.virtual_path
          ) do
            template.render(view, locals) { |*name| view._layout_for(*name) }
          end
        end
      end

      def render_with_layout(view, template, path, locals)
        layout  = path && find_layout(path, locals.keys, [formats.first])

        body = if layout
          ActiveSupport::Notifications.instrument("render_layout.action_view", identifier: layout.identifier) do
            view.view_flow.set(:layout, yield(layout))
            layout.render(view, locals) { |*name| view._layout_for(*name) }
          end
        else
          yield
        end
        build_rendered_template(body, template)
      end

      # This is the method which actually finds the layout using details in the lookup
      # context object. If no layout is found, it checks if at least a layout with
      # the given name exists across all details before raising the error.
      def find_layout(layout, keys, formats)
        resolve_layout(layout, keys, formats)
      end

      def resolve_layout(layout, keys, formats)
        details = @details.dup
        details[:formats] = formats

        case layout
        when String
          begin
            if layout.start_with?("/")
              ActiveSupport::Deprecation.warn "Rendering layouts from an absolute path is deprecated."
              @lookup_context.with_fallbacks.find_template(layout, nil, false, [], details)
            else
              @lookup_context.find_template(layout, nil, false, [], details)
            end
          rescue ActionView::MissingTemplate
            all_details = @details.merge(formats: @lookup_context.default_formats)
            raise unless template_exists?(layout, nil, false, [], **all_details)
          end
        when Proc
          resolve_layout(layout.call(@lookup_context, formats), keys, formats)
        else
          layout
        end
      end
  end
end
