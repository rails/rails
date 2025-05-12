# frozen_string_literal: true

# :markup: markdown

require "action_view"
require "action_controller"

module ActionDispatch
  # = Action Dispatch ExceptionsController
  #
  # This controller is used to render error pages, it is used by the Rails'
  # default `exceptions_app`.
  # To enable dynamic rendering of error pages, make sure the templates have the
  # `.erb` file extension, as previous versions of Rails were generating bare
  # html files.
  #
  # All Rails helpers are available in the views
  # (.e.g `stylesheet_link_tag`, `link_to` ...), and you also have access to all
  # routing url helpers.
  # The templates will be rendered with the `errors` layout, in the event that
  # this layout exists, otherwise no layout will be used.
  #
  # The controller will try to return the most suitable response based on the
  # request's format. If you'd like to render an error format differently,
  # you can create new error template (e.g. `422.json.erb`).
  # Any valid HTTP error code may be rendered with its own template, if that
  # template exists (e.g. `401.html.erb`).
  # If no template exists for an error code, a `404` with the `x-cascade` header
  # will be returned.
  #
  # The controller is stripped down on purpose and has the minimal
  # functionalities to display dynamic error pages as any other views in your
  # application.
  # If you have to perform logic before displaying an error page
  # (i.e. adding response headers), you can insert a middleware for that
  # controller only:
  #
  #   # lib/my_middleware.rb
  #   class MyMiddleware
  #     def initialize(app)
  #       @app = app
  #     end
  #
  #     def call(env)
  #       result = @app.call(env)
  #       result[1]["some-headers"] = "value"
  #       result
  #     end
  #   end
  #
  #   # config/application.rb
  #   ActionDispatch::ExceptionsController.use(MyMiddleware)
  #
  # In the event that you require more advanced control over,
  # creating your own {Exception App is preferred}[https://guides.rubyonrails.org/configuring.html#config-exceptions-app].
  class ExceptionsController < ActionController::Metal # :nodoc:
    include AbstractController::Rendering
    include ActionController::Rendering
    include ActionView::Layouts
    include ActionController::Renderers::All
    include ActionController::Head

    layout -> do
      layout_name = "layouts/errors"

      template_exists?(layout_name) ? layout_name : false
    end

    def self.local_prefixes
      []
    end

    def action_missing(status_code, *args)
      return pass_response unless Rack::Utils::HTTP_STATUS_CODES.include?(status_code.to_i)

      if template_for_content_type?(status_code)
        render(status_code, status: status_code)
      elsif generic_response.respond_to?("to_#{format.to_sym}")
        render(format.to_sym => generic_response(status_code), status: status_code)
      elsif template_exists?(status_code, formats: [:html])
        render(status_code, status: status_code, formats: [:html], content_type: :html)
      else
        pass_response
      end
    end

    private
      # This is a workaround to `LookupContext#template_exists?`. Because the legacy files were
      # called 404.html, the `html` part is considered as the handler, which leaves us with a empty
      # format, resulting in rendering that template for any kind of request's format.
      def template_for_content_type?(name)
        template = lookup_context.find_all(name).first
        return false unless template

        template_format = template.format
        if template_format.nil? && template.handler.is_a?(ActionView::Template::Handlers::Html)
          template_format = :html
        end

        format.to_sym == template_format
      end

      def pass_response
        head(:not_found, { ActionDispatch::Constants::X_CASCADE => "pass" })
      end

      def format
        request.format
      end

      def generic_response(status = nil)
        { status: status&.to_i, error: Rack::Utils::HTTP_STATUS_CODES.fetch(status.to_i, Rack::Utils::HTTP_STATUS_CODES[500]) }
      end
  end

  # # Action Dispatch PublicExceptions
  #
  # When called, this middleware renders an error page. By default if an HTML
  # response is expected it will render static error pages from the `/public`
  # directory. For example when this middleware receives a 500 response it will
  # render the template found in `/public/500.html`. If an internationalized
  # locale is set, this middleware will attempt to render the template in
  # `/public/500.<locale>.html`. If an internationalized template is not found it
  # will fall back on `/public/500.html`.
  #
  # When a request with a content type other than HTML is made, this middleware
  # will attempt to convert error information into the appropriate response type.
  class PublicExceptions
    attr_accessor :public_path

    def initialize(public_path, routes = nil)
      @public_path = public_path

      @controller = Class.new(ExceptionsController) do
        self.middleware_stack = ExceptionsController.middleware_stack
        self.view_paths = [public_path]

        if routes
          include(ActionController::UrlFor)
          include(routes.url_helpers)
        end
      end
    end

    def call(env)
      request = ActionDispatch::Request.new(env)
      status  = request.path_info[1..-1].to_i

      @controller.action(status).call(env)
    end
  end
end
