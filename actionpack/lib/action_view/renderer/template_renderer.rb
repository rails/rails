require 'set'
require 'active_support/core_ext/object/try'
require 'active_support/core_ext/array/wrap'
require 'action_view/renderer/abstract_renderer'

module ActionView
  class TemplateRenderer < AbstractRenderer #:nodoc:
    attr_reader :rendered

    def initialize(view)
      super
      @rendered = Set.new
    end

    def render(options)
      wrap_formats(options[:template] || options[:file]) do
        template = determine_template(options)
        render_template(template, options[:layout], options[:locals])
      end
    end

    def render_once(options)
      paths, locals = options[:once], options[:locals] || {}
      layout, keys  = options[:layout], locals.keys
      prefixes = options.fetch(:prefixes, @view.controller_prefixes)

      raise "render :once expects a String or an Array to be given" unless paths

      render_with_layout(layout, locals) do
        contents = []
        Array.wrap(paths).each do |path|
          template = find_template(path, prefixes, false, keys)
          contents << render_template(template, nil, locals) if @rendered.add?(template)
        end
        contents.join("\n")
      end
    end

    # Determine the template to be rendered using the given options.
    def determine_template(options) #:nodoc:
      keys = options[:locals].try(:keys) || []

      if options.key?(:text)
        Template::Text.new(options[:text], formats.try(:first))
      elsif options.key?(:file)
        with_fallbacks { find_template(options[:file], options[:prefixes], false, keys) }
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
      freeze_formats(template.formats, true)
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
        view.store_content_for(:layout, content)
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
      rescue ActionView::MissingTemplate => e
        update_details(:formats => nil) do
          raise unless template_exists?(layout)
        end
      end
    end
  end
end
