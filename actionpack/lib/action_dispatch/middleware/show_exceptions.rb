require 'active_support/core_ext/exception'
require 'active_support/notifications'
require 'action_dispatch/http/request'

module ActionDispatch
  # This middleware rescues any exception returned by the application and renders
  # nice exception pages if it's being rescued locally.
  class ShowExceptions
    RESCUES_TEMPLATE_PATH = File.join(File.dirname(__FILE__), 'templates')

    cattr_accessor :rescue_responses
    @@rescue_responses = Hash.new(:internal_server_error)
    @@rescue_responses.update({
      'ActionController::RoutingError'             => :not_found,
      'AbstractController::ActionNotFound'         => :not_found,
      'ActiveRecord::RecordNotFound'               => :not_found,
      'ActiveRecord::StaleObjectError'             => :conflict,
      'ActiveRecord::RecordInvalid'                => :unprocessable_entity,
      'ActiveRecord::RecordNotSaved'               => :unprocessable_entity,
      'ActionController::MethodNotAllowed'         => :method_not_allowed,
      'ActionController::NotImplemented'           => :not_implemented,
      'ActionController::InvalidAuthenticityToken' => :unprocessable_entity
    })

    cattr_accessor :rescue_templates
    @@rescue_templates = Hash.new('diagnostics')
    @@rescue_templates.update({
      'ActionView::MissingTemplate'         => 'missing_template',
      'ActionController::RoutingError'      => 'routing_error',
      'AbstractController::ActionNotFound'  => 'unknown_action',
      'ActionView::Template::Error'         => 'template_error'
    })

    FAILSAFE_RESPONSE = [500, {'Content-Type' => 'text/html'},
      ["<html><body><h1>500 Internal Server Error</h1>" <<
       "If you are the administrator of this website, then please read this web " <<
       "application's log file and/or the web server's log file to find out what " <<
       "went wrong.</body></html>"]]

    def initialize(app, consider_all_requests_local = false)
      @app = app
      @consider_all_requests_local = consider_all_requests_local
    end

    def call(env)
      begin
        status, headers, body = @app.call(env)
        exception = nil

        # Only this middleware cares about RoutingError. So, let's just raise
        # it here.
        if headers['X-Cascade'] == 'pass'
           raise ActionController::RoutingError, "No route matches #{env['PATH_INFO'].inspect}"
        end
      rescue Exception => exception
        raise exception if env['action_dispatch.show_exceptions'] == false
      end

      exception ? render_exception(env, exception) : [status, headers, body]
    end

    private
      def render_exception(env, exception)
        log_error(exception)

        request = Request.new(env)
        if @consider_all_requests_local || request.local?
          rescue_action_locally(request, exception)
        else
          rescue_action_in_public(exception)
        end
      rescue Exception => failsafe_error
        $stderr.puts "Error during failsafe response: #{failsafe_error}\n  #{failsafe_error.backtrace * "\n  "}"
        FAILSAFE_RESPONSE
      end

      # Render detailed diagnostics for unhandled exceptions rescued from
      # a controller action.
      def rescue_action_locally(request, exception)
        template = ActionView::Base.new([RESCUES_TEMPLATE_PATH],
          :request => request,
          :exception => exception,
          :application_trace => application_trace(exception),
          :framework_trace => framework_trace(exception),
          :full_trace => full_trace(exception)
        )
        file = "rescues/#{@@rescue_templates[exception.class.name]}.erb"
        body = template.render(:file => file, :layout => 'rescues/layout.erb')
        render(status_code(exception), body)
      end

      # Attempts to render a static error page based on the
      # <tt>status_code</tt> thrown, or just return headers if no such file
      # exists. At first, it will try to render a localized static page.
      # For example, if a 500 error is being handled Rails and locale is :da,
      # it will first attempt to render the file at <tt>public/500.da.html</tt>
      # then attempt to render <tt>public/500.html</tt>. If none of them exist,
      # the body of the response will be left empty.
      def rescue_action_in_public(exception)
        status = status_code(exception)
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

      def status_code(exception)
        Rack::Utils.status_code(@@rescue_responses[exception.class.name])
      end

      def render(status, body)
        [status, {'Content-Type' => 'text/html', 'Content-Length' => body.bytesize.to_s}, [body]]
      end

      def public_path
        defined?(Rails.public_path) ? Rails.public_path : 'public_path'
      end

      def log_error(exception)
        return unless logger

        ActiveSupport::Deprecation.silence do
          message = "\n#{exception.class} (#{exception.message}):\n"
          message << exception.annoted_source_code.to_s if exception.respond_to?(:annoted_source_code)
          message << "  " << application_trace(exception).join("\n  ")
          logger.fatal("#{message}\n\n")
        end
      end

      def application_trace(exception)
        clean_backtrace(exception, :silent)
      end

      def framework_trace(exception)
        clean_backtrace(exception, :noise)
      end

      def full_trace(exception)
        clean_backtrace(exception, :all)
      end

      def clean_backtrace(exception, *args)
        defined?(Rails) && Rails.respond_to?(:backtrace_cleaner) ?
          Rails.backtrace_cleaner.clean(exception.backtrace, *args) :
          exception.backtrace
      end

      def logger
        defined?(Rails.logger) ? Rails.logger : Logger.new($stderr)
      end
  end
end
