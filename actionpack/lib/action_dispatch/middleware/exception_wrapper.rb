require 'action_controller/metal/exceptions'
require 'active_support/core_ext/exception'

module ActionDispatch
  class ExceptionWrapper
    cattr_accessor :rescue_responses
    @@rescue_responses = Hash.new(:internal_server_error)
    @@rescue_responses.merge!(
      'ActionController::RoutingError'             => :not_found,
      'AbstractController::ActionNotFound'         => :not_found,
      'ActionController::MethodNotAllowed'         => :method_not_allowed,
      'ActionController::NotImplemented'           => :not_implemented,
      'ActionController::InvalidAuthenticityToken' => :unprocessable_entity
    )

    cattr_accessor :rescue_templates
    @@rescue_templates = Hash.new('diagnostics')
    @@rescue_templates.merge!(
      'ActionView::MissingTemplate'         => 'missing_template',
      'ActionController::RoutingError'      => 'routing_error',
      'AbstractController::ActionNotFound'  => 'unknown_action',
      'ActionView::Template::Error'         => 'template_error'
    )

    attr_reader :env, :exception

    def initialize(env, exception)
      @env = env
      @exception = original_exception(exception)
    end

    def rescue_template
      @@rescue_templates[@exception.class.name]
    end

    def status_code
      Rack::Utils.status_code(@@rescue_responses[@exception.class.name])
    end

    def application_trace
      clean_backtrace(:silent)
    end

    def framework_trace
      clean_backtrace(:noise)
    end

    def full_trace
      clean_backtrace(:all)
    end

    private

    def original_exception(exception)
      if registered_original_exception?(exception)
        exception.original_exception
      else
        exception
      end
    end

    def registered_original_exception?(exception)
      exception.respond_to?(:original_exception) && @@rescue_responses.has_key?(exception.original_exception.class.name)
    end

    def clean_backtrace(*args)
      if backtrace_cleaner
        backtrace_cleaner.clean(@exception.backtrace, *args)
      else
        @exception.backtrace
      end
    end

    def backtrace_cleaner
      @backtrace_cleaner ||= @env['action_dispatch.backtrace_cleaner']
    end
  end
end