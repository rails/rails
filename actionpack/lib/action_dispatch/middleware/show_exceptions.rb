require 'action_controller/metal/exceptions'
require 'action_dispatch/http/request'
require 'action_dispatch/middleware/exception_wrapper'
require 'active_support/deprecation'

module ActionDispatch
  # This middleware rescues any exception returned by the application and renders
  # nice exception pages if it's being rescued locally.
  class ShowExceptions
    RESCUES_TEMPLATE_PATH = File.join(File.dirname(__FILE__), 'templates')

    FAILSAFE_RESPONSE = [500, {'Content-Type' => 'text/html'},
      ["<html><body><h1>500 Internal Server Error</h1>" <<
       "If you are the administrator of this website, then please read this web " <<
       "application's log file and/or the web server's log file to find out what " <<
       "went wrong.</body></html>"]]

    class << self
      def rescue_responses
        ActiveSupport::Deprecation.warn "ActionDispatch::ShowExceptions.rescue_responses is deprecated. " \
          "Please configure your exceptions using a railtie or in your application config instead."
        ExceptionWrapper.rescue_responses
      end

      def rescue_templates
        ActiveSupport::Deprecation.warn "ActionDispatch::ShowExceptions.rescue_templates is deprecated. " \
          "Please configure your exceptions using a railtie or in your application config instead."
        ExceptionWrapper.rescue_templates
      end
    end

    def initialize(app, consider_all_requests_local = nil)
      ActiveSupport::Deprecation.warn "Passing consider_all_requests_local option to ActionDispatch::ShowExceptions middleware no longer works" unless consider_all_requests_local.nil?
      @app = app
    end

    def call(env)
      begin
        status, headers, body = @app.call(env)
        exception = nil

        # Only this middleware cares about RoutingError. So, let's just raise
        # it here.
        if headers['X-Cascade'] == 'pass'
           raise ActionController::RoutingError, "No route matches [#{env['REQUEST_METHOD']}] #{env['PATH_INFO'].inspect}"
        end
      rescue Exception => exception
        raise exception if env['action_dispatch.show_exceptions'] == false
      end

      exception ? render_exception(env, exception) : [status, headers, body]
    end

    private
      def render_exception(env, exception)
        wrapper = ExceptionWrapper.new(env, exception)
        log_error(env, wrapper)

        if env['action_dispatch.show_detailed_exceptions'] == true
          rescue_action_diagnostics(wrapper)
        else
          rescue_action_error_page(wrapper)
        end
      rescue Exception => failsafe_error
        $stderr.puts "Error during failsafe response: #{failsafe_error}\n  #{failsafe_error.backtrace * "\n  "}"
        FAILSAFE_RESPONSE
      end

      # Render detailed diagnostics for unhandled exceptions rescued from
      # a controller action.
      def rescue_action_diagnostics(wrapper)
        template = ActionView::Base.new([RESCUES_TEMPLATE_PATH],
          :request => Request.new(wrapper.env),
          :exception => wrapper.exception,
          :application_trace => wrapper.application_trace,
          :framework_trace => wrapper.framework_trace,
          :full_trace => wrapper.full_trace
        )
        file = "rescues/#{wrapper.rescue_template}"
        body = template.render(:template => file, :layout => 'rescues/layout')
        render(wrapper.status_code, body)
      end

      # Attempts to render a static error page based on the
      # <tt>status_code</tt> thrown, or just return headers if no such file
      # exists. At first, it will try to render a localized static page.
      # For example, if a 500 error is being handled Rails and locale is :da,
      # it will first attempt to render the file at <tt>public/500.da.html</tt>
      # then attempt to render <tt>public/500.html</tt>. If none of them exist,
      # the body of the response will be left empty.
      def rescue_action_error_page(wrapper)
        status = wrapper.status_code
        locale_path = "#{public_path}/#{status}.#{I18n.locale}.html" if I18n.locale
        path = "#{public_path}/#{status}.html"

        if locale_path && File.exist?(locale_path)
          render(status, File.read(locale_path))
        elsif File.exist?(path)
          render(status, File.read(path))
        else
          render(status, '')
        end
      end

      def render(status, body)
        [status, {'Content-Type' => "text/html; charset=#{Response.default_charset}", 'Content-Length' => body.bytesize.to_s}, [body]]
      end

      def public_path
        defined?(Rails.public_path) ? Rails.public_path : 'public_path'
      end

      def log_error(env, wrapper)
        logger = logger(env)
        return unless logger

        exception = wrapper.exception

        ActiveSupport::Deprecation.silence do
          message = "\n#{exception.class} (#{exception.message}):\n"
          message << exception.annoted_source_code.to_s if exception.respond_to?(:annoted_source_code)
          message << "  " << wrapper.application_trace.join("\n  ")
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
