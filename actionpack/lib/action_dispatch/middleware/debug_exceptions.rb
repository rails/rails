require 'action_dispatch/http/request'
require 'action_dispatch/middleware/exception_wrapper'
require 'action_dispatch/routing/inspector'

module ActionDispatch
  # This middleware is responsible for logging exceptions and
  # showing a debugging page in case the request is local.
  class DebugExceptions
    RESCUES_TEMPLATE_PATH = File.expand_path('../templates', __FILE__)

    def initialize(app, routes_app = nil)
      @app        = app
      @routes_app = routes_app
    end

    def call(env)
      _, headers, body = response = @app.call(env)

      if headers['X-Cascade'] == 'pass'
        body.close if body.respond_to?(:close)
        raise ActionController::RoutingError, "No route matches [#{env['REQUEST_METHOD']}] #{env['PATH_INFO'].inspect}"
      end

      response
    rescue Exception => exception
      raise exception if env['action_dispatch.show_exceptions'] == false
      ExceptionHandler.new(env, exception, @routes_app).log_and_render
    end

    class ExceptionHandler < Struct.new(:env, :exception, :routes_app)
      delegate :status_code, to: :wrapper

      def log_and_render
        log_error

        if env['action_dispatch.show_detailed_exceptions']
          render
        else
          raise exception
        end
      end

      def to_html
        ActionView::Base.new([RESCUES_TEMPLATE_PATH],
          request:           request,
          exception:         wrapper.exception,
          application_trace: wrapper.application_trace,
          framework_trace:   wrapper.framework_trace,
          full_trace:        wrapper.full_trace,
          routes_inspector:  routes_inspector,
          source_extract:    wrapper.source_extract,
          line_number:       wrapper.line_number,
          file:              wrapper.file
        )
      end

      def format
        request.xhr? ? "text/plain" : "text/html"
      end

      def body
        if request.xhr?
          to_html.render(template: file, layout: false, formats: [:text])
        else
          to_html.render(template: file, layout: 'rescues/layout')
        end
      end

      private
      def render
        [
          status_code,
          {
            'Content-Type'   => "#{format}; charset=#{Response.default_charset}",
            'Content-Length' => body.bytesize.to_s
          },
          [body]
        ]
      end

      def file
        "rescues/#{wrapper.rescue_template}"
      end

      def wrapper
        ExceptionWrapper.new(env, exception)
      end

      def request
        Request.new(env)
      end

      def logger
        env['action_dispatch.logger'] || stderr_logger
      end

      def stderr_logger
        @stderr_logger ||= ActiveSupport::Logger.new($stderr)
      end

      def routes_inspector?
        @routes_app.respond_to?(:routes) &&
        (
          exception.is_a?(ActionController::RoutingError) ||
          exception.is_a?(ActionView::Template::Error)
        )
      end

      def routes_inspector
        if routes_inspector?
          ActionDispatch::Routing::RoutesInspector.new(@routes_app.routes.routes)
        end
      end

      def log_error
        return unless logger

        exception = wrapper.exception

        trace = wrapper.application_trace
        trace = wrapper.framework_trace if trace.empty?

        ActiveSupport::Deprecation.silence do
          message = "\n#{exception.class} (#{exception.message}):\n"
          message << exception.annoted_source_code.to_s if exception.respond_to?(:annoted_source_code)
          message << "  " << trace.join("\n  ")
          logger.fatal("#{message}\n\n")
        end
      end
    end
  end
end
