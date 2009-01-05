module ActionController #:nodoc:
  # Actions that fail to perform as expected throw exceptions. These
  # exceptions can either be rescued for the public view (with a nice
  # user-friendly explanation) or for the developers view (with tons of
  # debugging information). The developers view is already implemented by
  # the Action Controller, but the public view should be tailored to your
  # specific application.
  #
  # The default behavior for public exceptions is to render a static html
  # file with the name of the error code thrown.  If no such file exists, an
  # empty response is sent with the correct status code.
  #
  # You can override what constitutes a local request by overriding the
  # <tt>local_request?</tt> method in your own controller. Custom rescue
  # behavior is achieved by overriding the <tt>rescue_action_in_public</tt>
  # and <tt>rescue_action_locally</tt> methods.
  module Rescue
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

    RESCUES_TEMPLATE_PATH = ActionView::Template::EagerPath.new(
      File.join(File.dirname(__FILE__), "templates"))

    def self.included(base) #:nodoc:
      base.cattr_accessor :rescue_responses
      base.rescue_responses = Hash.new(DEFAULT_RESCUE_RESPONSE)
      base.rescue_responses.update DEFAULT_RESCUE_RESPONSES

      base.cattr_accessor :rescue_templates
      base.rescue_templates = Hash.new(DEFAULT_RESCUE_TEMPLATE)
      base.rescue_templates.update DEFAULT_RESCUE_TEMPLATES

      base.extend(ClassMethods)
      base.send :include, ActiveSupport::Rescuable

      base.class_eval do
        alias_method_chain :perform_action, :rescue
      end
    end

    module ClassMethods
      def call_with_exception(env, exception) #:nodoc:
        request = env["action_controller.rescue.request"] ||= Request.new(env)
        response = env["action_controller.rescue.response"] ||= Response.new
        new.process(request, response, :rescue_action, exception)
      end
    end

    protected
      # Exception handler called when the performance of an action raises
      # an exception.
      def rescue_action(exception)
        rescue_with_handler(exception) ||
          rescue_action_without_handler(exception)
      end

      # Overwrite to implement custom logging of errors. By default
      # logs as fatal.
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

      # Overwrite to implement public exception handling (for requests
      # answering false to <tt>local_request?</tt>).  By default will call
      # render_optional_error_file.  Override this method to provide more
      # user friendly error messages.
      def rescue_action_in_public(exception) #:doc:
        render_optional_error_file response_code_for_rescue(exception)
      end

      # Attempts to render a static error page based on the
      # <tt>status_code</tt> thrown, or just return headers if no such file
      # exists. For example, if a 500 error is being handled Rails will first
      # attempt to render the file at <tt>public/500.html</tt>. If the file
      # doesn't exist, the body of the response will be left empty.
      def render_optional_error_file(status_code)
        status = interpret_status(status_code)
        path = "#{Rails.public_path}/#{status.to_s[0,3]}.html"
        if File.exist?(path)
          render :file => path, :status => status, :content_type => Mime::HTML
        else
          head status
        end
      end

      # True if the request came from localhost, 127.0.0.1. Override this
      # method if you wish to redefine the meaning of a local request to
      # include remote IP addresses or other criteria.
      def local_request? #:doc:
        request.remote_addr == LOCALHOST && request.remote_ip == LOCALHOST
      end

      # Render detailed diagnostics for unhandled exceptions rescued from
      # a controller action.
      def rescue_action_locally(exception)
        @template.instance_variable_set("@exception", exception)
        @template.instance_variable_set("@rescues_path", RESCUES_TEMPLATE_PATH)
        @template.instance_variable_set("@contents",
          @template.render(:file => template_path_for_local_rescue(exception)))

        response.content_type = Mime::HTML
        render_for_file(rescues_path("layout"),
          response_code_for_rescue(exception))
      end

      def rescue_action_without_handler(exception)
        log_error(exception) if logger
        erase_results if performed?

        # Let the exception alter the response if it wants.
        # For example, MethodNotAllowed sets the Allow header.
        if exception.respond_to?(:handle_response!)
          exception.handle_response!(response)
        end

        if consider_all_requests_local || local_request?
          rescue_action_locally(exception)
        else
          rescue_action_in_public(exception)
        end
      end

    private
      def perform_action_with_rescue #:nodoc:
        perform_action_without_rescue
      rescue Exception => exception
        rescue_action(exception)
      end

      def rescues_path(template_name)
        RESCUES_TEMPLATE_PATH["rescues/#{template_name}.erb"]
      end

      def template_path_for_local_rescue(exception)
        rescues_path(rescue_templates[exception.class.name])
      end

      def response_code_for_rescue(exception)
        rescue_responses[exception.class.name]
      end

      def clean_backtrace(exception)
        defined?(Rails) && Rails.respond_to?(:backtrace_cleaner) ?
          Rails.backtrace_cleaner.clean(exception.backtrace) :
          exception.backtrace
      end
  end
end
