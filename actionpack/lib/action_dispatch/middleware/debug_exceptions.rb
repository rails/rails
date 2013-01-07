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
      render_exception(env, exception)
    end

    private

    def render_exception(env, exception)
      wrapper = ExceptionWrapper.new(env, exception)
      log_error(env, wrapper)

      if env['action_dispatch.show_detailed_exceptions']
        template = ActionView::Base.new([RESCUES_TEMPLATE_PATH],
          :request => Request.new(env),
          :exception => wrapper.exception,
          :application_trace => wrapper.application_trace,
          :framework_trace => wrapper.framework_trace,
          :full_trace => wrapper.full_trace,
          :routes_inspector => routes_inspector(exception),
          :source_extract => wrapper.source_extract,
          :line_number => wrapper.line_number,
          :file => wrapper.file
        )
        file = "rescues/#{wrapper.rescue_template}"
        body = template.render(:template => file, :layout => 'rescues/layout')
        render(wrapper.status_code, body)
      else
        raise exception
      end
    end

    def render(status, body)
      [status, {'Content-Type' => "text/html; charset=#{Response.default_charset}", 'Content-Length' => body.bytesize.to_s}, [body]]
    end

    def log_error(env, wrapper)
      logger = logger(env)
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

    def logger(env)
      env['action_dispatch.logger'] || stderr_logger
    end

    def stderr_logger
      @stderr_logger ||= ActiveSupport::Logger.new($stderr)
    end

    def routes_inspector(exception)
      if @routes_app.respond_to?(:routes) && (exception.is_a?(ActionController::RoutingError) || exception.is_a?(ActionView::Template::Error))
        ActionDispatch::Routing::RoutesInspector.new(@routes_app.routes.routes)
      end
    end
  end
end
