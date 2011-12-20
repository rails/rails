require 'action_dispatch/http/request'
require 'action_dispatch/middleware/exception_wrapper'

module ActionDispatch
  # This middleware is responsible for logging exceptions and
  # showing a debugging page in case the request is local.
  class DebugExceptions
    RESCUES_TEMPLATE_PATH = File.join(File.dirname(__FILE__), 'templates')

    def initialize(app)
      @app = app
    end

    def call(env)
      begin
        response = @app.call(env)

        if response[1]['X-Cascade'] == 'pass'
          body = response[2]
          body.close if body.respond_to?(:close)
          raise ActionController::RoutingError, "No route matches [#{env['REQUEST_METHOD']}] #{env['PATH_INFO'].inspect}"
        end
      rescue Exception => exception
        raise exception if env['action_dispatch.show_exceptions'] == false
      end

      exception ? render_exception(env, exception) : response
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
          :full_trace => wrapper.full_trace
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
      @stderr_logger ||= Logger.new($stderr)
    end
  end
end
