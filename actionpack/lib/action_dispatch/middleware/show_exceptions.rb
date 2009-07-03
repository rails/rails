require "active_support/core_ext/exception"

module ActionDispatch
  class ShowExceptions
    include StatusCodes

    LOCALHOST = '127.0.0.1'.freeze

    RESCUES_TEMPLATE_PATH = File.join(File.dirname(__FILE__), 'templates')

    cattr_accessor :rescue_responses
    @@rescue_responses = Hash.new(:internal_server_error)
    @@rescue_responses.update({
      'ActionController::RoutingError'             => :not_found,
      # TODO: Clean this up after the switch
      ActionController::UnknownAction.name         => :not_found,
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
      ActionController::UnknownAction.name  => 'unknown_action',
      'ActionView::TemplateError'           => 'template_error'
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
      @app.call(env)
    rescue Exception => exception
      raise exception if env['action_dispatch.show_exceptions'] == false
      render_exception(env, exception)
    end

    private
      def render_exception(env, exception)
        log_error(exception)

        request = Request.new(env)
        if @consider_all_requests_local || local_request?(request)
          rescue_action_locally(request, exception)
        else
          rescue_action_in_public(exception)
        end
      rescue Exception => failsafe_error
        $stderr.puts "Error during failsafe response: #{failsafe_error}"
        FAILSAFE_RESPONSE
      end

      # Render detailed diagnostics for unhandled exceptions rescued from
      # a controller action.
      def rescue_action_locally(request, exception)
        template = ActionView::Base.new([RESCUES_TEMPLATE_PATH],
          :request => request,
          :exception => exception
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

      # True if the request came from localhost, 127.0.0.1.
      def local_request?(request)
        request.remote_addr == LOCALHOST && request.remote_ip == LOCALHOST
      end

      def status_code(exception)
        interpret_status(@@rescue_responses[exception.class.name]).to_i
      end

      def render(status, body)
        [status, {'Content-Type' => 'text/html', 'Content-Length' => body.length.to_s}, [body]]
      end

      def public_path
        defined?(Rails.public_path) ? Rails.public_path : 'public_path'
      end

      def log_error(exception)
        return unless logger

        ActiveSupport::Deprecation.silence do
          if ActionView::TemplateError === exception
            logger.fatal(exception.to_s)
          else
            logger.fatal(
              "\n#{exception.class} (#{exception.message}):\n  " +
              clean_backtrace(exception).join("\n  ") + "\n\n"
            )
          end
        end
      end

      def clean_backtrace(exception)
        defined?(Rails) && Rails.respond_to?(:backtrace_cleaner) ?
          Rails.backtrace_cleaner.clean(exception.backtrace) :
          exception.backtrace
      end

      def logger
        defined?(Rails.logger) ? Rails.logger : Logger.new($stderr)
      end
  end
end
