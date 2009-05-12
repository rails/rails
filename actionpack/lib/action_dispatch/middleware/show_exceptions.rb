module ActionDispatch
  class ShowExceptions
    include StatusCodes

    LOCALHOST = '127.0.0.1'.freeze

    DEFAULT_RESCUE_RESPONSE = :internal_server_error
    DEFAULT_RESCUE_RESPONSES = {
      'ActionController::RoutingError'             => :not_found,
      'ActionController::UnknownAction'            => :not_found,
      'ActiveRecord::RecordNotFound'               => :not_found,
      'ActiveRecord::StaleObjectError'             => :conflict,
      'ActiveRecord::RecordInvalid'                => :unprocessable_entity,
      'ActiveRecord::RecordNotSaved'               => :unprocessable_entity,
      'ActionController::MethodNotAllowed'         => :method_not_allowed,
      'ActionController::NotImplemented'           => :not_implemented,
      'ActionController::InvalidAuthenticityToken' => :unprocessable_entity
    }

    DEFAULT_RESCUE_TEMPLATE = 'diagnostics'
    DEFAULT_RESCUE_TEMPLATES = {
      'ActionView::MissingTemplate'       => 'missing_template',
      'ActionController::RoutingError'    => 'routing_error',
      'ActionController::UnknownAction'   => 'unknown_action',
      'ActionView::TemplateError'         => 'template_error'
    }

    RESCUES_TEMPLATE_PATH = File.join(File.dirname(__FILE__), 'templates')

    cattr_accessor :rescue_responses
    @@rescue_responses = Hash.new(DEFAULT_RESCUE_RESPONSE)
    @@rescue_responses.update DEFAULT_RESCUE_RESPONSES

    cattr_accessor :rescue_templates
    @@rescue_templates = Hash.new(DEFAULT_RESCUE_TEMPLATE)
    @@rescue_templates.update DEFAULT_RESCUE_TEMPLATES

    def initialize(app, consider_all_requests_local = false)
      @app = app
      @consider_all_requests_local = consider_all_requests_local
    end

    def call(env)
      @app.call(env)
    rescue Exception => exception
      raise exception if env['rack.test']

      log_error(exception) if logger

      request = Request.new(env)
      if @consider_all_requests_local || local_request?(request)
        rescue_action_locally(request, exception)
      else
        rescue_action_in_public(exception)
      end
    end

    private
      # Render detailed diagnostics for unhandled exceptions rescued from
      # a controller action.
      def rescue_action_locally(request, exception)
        template = ActionView::Base.new([RESCUES_TEMPLATE_PATH],
          :template => template,
          :request => request,
          :exception => exception
        )
        file = "rescues/#{@@rescue_templates[exception.class.name]}.erb"
        body = template.render(:file => file, :layout => 'rescues/layout.erb')

        headers = {'Content-Type' => 'text/html', 'Content-Length' => body.length.to_s}
        status = status_code(exception)

        [status, headers, body]
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
          render_public_file(status, locale_path)
        elsif File.exist?(path)
          render_public_file(status, path)
        else
          [status, {'Content-Type' => 'text/html', 'Content-Length' => '0'}, []]
        end
      end

      # True if the request came from localhost, 127.0.0.1.
      def local_request?(request)
        request.remote_addr == LOCALHOST && request.remote_ip == LOCALHOST
      end

      def render_public_file(status, path)
        body = File.read(path)
        [status, {'Content-Type' => 'text/html', 'Content-Length' => body.length.to_s}, body]
      end

      def status_code(exception)
        interpret_status(@@rescue_responses[exception.class.name]).to_i
      end

      def public_path
        if defined?(Rails)
          Rails.public_path
        else
          "public"
        end
      end

      def log_error(exception) #:doc:
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
        if defined?(Rails.logger)
          Rails.logger
        end
      end
  end
end
