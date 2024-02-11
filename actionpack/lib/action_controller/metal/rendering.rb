# frozen_string_literal: true

# :markup: markdown

module ActionController
  module Rendering
    extend ActiveSupport::Concern

    RENDER_FORMATS_IN_PRIORITY = [:body, :plain, :html]

    module ClassMethods
      # Documentation at ActionController::Renderer#render
      delegate :render, to: :renderer

      # Returns a renderer instance (inherited from ActionController::Renderer) for
      # the controller.
      attr_reader :renderer

      def setup_renderer! # :nodoc:
        @renderer = Renderer.for(self)
      end

      def inherited(klass)
        klass.setup_renderer!
        super
      end
    end

    # Renders a template and assigns the result to `self.response_body`.
    #
    # If no rendering mode option is specified, the template will be derived from
    # the first argument.
    #
    #     render "posts/show"
    #     # => renders app/views/posts/show.html.erb
    #
    #     # In a PostsController action...
    #     render :show
    #     # => renders app/views/posts/show.html.erb
    #
    # If the first argument responds to `render_in`, the template will be rendered
    # by calling `render_in` with the current view context.
    #
    #     class Greeting
    #       def render_in(view_context)
    #         view_context.render html: "<h1>Hello, World</h1>"
    #       end
    #
    #       def format
    #         :html
    #       end
    #     end
    #
    #     render(Greeting.new)
    #     # => "<h1>Hello, World</h1>"
    #
    #     render(renderable: Greeting.new)
    #     # => "<h1>Hello, World</h1>"
    #
    # #### Rendering Mode
    #
    # `:partial`
    # :   See ActionView::PartialRenderer for details.
    #
    #         render partial: "posts/form", locals: { post: Post.new }
    #         # => renders app/views/posts/_form.html.erb
    #
    # `:file`
    # :   Renders the contents of a file. This option should **not** be used with
    #     unsanitized user input.
    #
    #         render file: "/path/to/some/file"
    #         # => renders /path/to/some/file
    #
    # `:inline`
    # :   Renders an ERB template string.
    #
    #         @name = "World"
    #         render inline: "<h1>Hello, <%= @name %>!</h1>"
    #         # => renders "<h1>Hello, World!</h1>"
    #
    # `:body`
    # :   Renders the provided text, and sets the content type as `text/plain`.
    #
    #         render body: "Hello, World!"
    #         # => renders "Hello, World!"
    #
    # `:plain`
    # :   Renders the provided text, and sets the content type as `text/plain`.
    #
    #         render plain: "Hello, World!"
    #         # => renders "Hello, World!"
    #
    # `:html`
    # :   Renders the provided HTML string, and sets the content type as
    #     `text/html`. If the string is not `html_safe?`, performs HTML escaping on
    #     the string before rendering.
    #
    #         render html: "<h1>Hello, World!</h1>".html_safe
    #         # => renders "<h1>Hello, World!</h1>"
    #
    #         render html: "<h1>Hello, World!</h1>"
    #         # => renders "&lt;h1&gt;Hello, World!&lt;/h1&gt;"
    #
    # `:json`
    # :   Renders the provided object as JSON, and sets the content type as
    #     `application/json`. If the object is not a string, it will be converted to
    #     JSON by calling `to_json`.
    #
    #         render json: { hello: "world" }
    #         # => renders "{\"hello\":\"world\"}"
    #
    # `:renderable`
    # :   Renders the provided object by calling `render_in` with the current view
    #     context. The response format is determined by calling `format` on the
    #     renderable if it responds to `format`, falling back to `text/html` by
    #     default.
    #
    #         render renderable: Greeting.new
    #         # => renders "<h1>Hello, World</h1>"
    #
    #
    # By default, when a rendering mode is specified, no layout template is
    # rendered.
    #
    # #### Options
    #
    # `:assigns`
    # :   Hash of instance variable assignments for the template.
    #
    #         render inline: "<h1>Hello, <%= @name %>!</h1>", assigns: { name: "World" }
    #         # => renders "<h1>Hello, World!</h1>"
    #
    # `:locals`
    # :   Hash of local variable assignments for the template.
    #
    #         render inline: "<h1>Hello, <%= name %>!</h1>", locals: { name: "World" }
    #         # => renders "<h1>Hello, World!</h1>"
    #
    # `:layout`
    # :   The layout template to render. Can also be `false` or `true` to disable or
    #     (re)enable the default layout template.
    #
    #         render "posts/show", layout: "holiday"
    #         # => renders app/views/posts/show.html.erb with the app/views/layouts/holiday.html.erb layout
    #
    #         render "posts/show", layout: false
    #         # => renders app/views/posts/show.html.erb with no layout
    #
    #         render inline: "<h1>Hello, World!</h1>", layout: true
    #         # => renders "<h1>Hello, World!</h1>" with the default layout
    #
    # `:status`
    # :   The HTTP status code to send with the response. Can be specified as a
    #     number or as the status name in Symbol form. Defaults to 200.
    #
    #         render "posts/new", status: 422
    #         # => renders app/views/posts/new.html.erb with HTTP status code 422
    #
    #         render "posts/new", status: :unprocessable_entity
    #         # => renders app/views/posts/new.html.erb with HTTP status code 422
    #
    #--
    # Check for double render errors and set the content_type after rendering.
    def render(*args)
      raise ::AbstractController::DoubleRenderError if response_body
      super
    end

    # Similar to #render, but only returns the rendered template as a string,
    # instead of setting `self.response_body`.
    #--
    # Override render_to_string because body can now be set to a Rack body.
    def render_to_string(*)
      result = super
      if result.respond_to?(:each)
        string = +""
        result.each { |r| string << r }
        string
      else
        result
      end
    end

    def render_to_body(options = {}) # :nodoc:
      super || _render_in_priorities(options) || " "
    end

    private
      # Before processing, set the request formats in current controller formats.
      def process_action(*) # :nodoc:
        self.formats = request.formats.filter_map(&:ref)
        super
      end

      def _process_variant(options)
        if defined?(request) && !request.nil? && request.variant.present?
          options[:variant] = request.variant
        end
      end

      def _render_in_priorities(options)
        RENDER_FORMATS_IN_PRIORITY.each do |format|
          return options[format] if options.key?(format)
        end

        nil
      end

      def _set_html_content_type
        self.content_type = Mime[:html].to_s
      end

      def _set_rendered_content_type(format)
        if format && !response.media_type
          self.content_type = format.to_s
        end
      end

      def _set_vary_header
        if response.headers["Vary"].blank? && request.should_apply_vary_header?
          response.headers["Vary"] = "Accept"
        end
      end

      # Normalize both text and status options.
      def _normalize_options(options)
        _normalize_text(options)

        if options[:html]
          options[:html] = ERB::Util.html_escape(options[:html])
        end

        if options[:status]
          options[:status] = Rack::Utils.status_code(options[:status])
        end

        super
      end

      def _normalize_text(options)
        RENDER_FORMATS_IN_PRIORITY.each do |format|
          if options.key?(format) && options[format].respond_to?(:to_text)
            options[format] = options[format].to_text
          end
        end
      end

      # Process controller specific options, as status, content-type and location.
      def _process_options(options)
        status, content_type, location = options.values_at(:status, :content_type, :location)

        self.status = status if status
        self.content_type = content_type if content_type
        headers["Location"] = url_for(location) if location

        super
      end
  end
end
