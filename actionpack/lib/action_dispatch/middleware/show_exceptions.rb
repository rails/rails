require 'action_dispatch/http/request'
require 'action_dispatch/middleware/exception_wrapper'
require 'active_support/deprecation'

module ActionDispatch
  # This middleware rescues any exception returned by the application
  # and calls a rack application that will wrap it in a format for the end user.
  #
  # The rack application should be passed as parameter on initialization
  # of ShowExceptions. Everytime there is an exception, ShowExceptions will
  # store the exception in env["action_dispatch.exception"], rewrite the
  # PATH_INFO to the exception status code and call the rack app.
  class ShowExceptions
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

    def initialize(app, exceptions_app = nil)
      if [true, false].include?(exceptions_app)
        ActiveSupport::Deprecation.warn "Passing consider_all_requests_local option to ActionDispatch::ShowExceptions middleware no longer works"
        exceptions_app = nil
      end

      if exceptions_app.nil?
        raise ArgumentError, "You need to pass an exceptions_app when initializing ActionDispatch::ShowExceptions. " \
          "In case you want to render pages from a public path, you can use ActionDispatch::PublicExceptions.new('path/to/public')"
      end

      @app = app
      @exceptions_app = exceptions_app
    end

    def call(env)
      begin
        response  = @app.call(env)
      rescue Exception => exception
        raise exception if env['action_dispatch.show_exceptions'] == false
      end

      response || render_exception(env, exception)
    end

    private

    # Define this method because some plugins were monkey patching it.
    # Remove this after 3.2 is out with the other deprecations in this class.
    def status_code(*)
    end

    def render_exception(env, exception)
      wrapper = ExceptionWrapper.new(env, exception)
      env["action_dispatch.exception"] = wrapper.exception
      env["PATH_INFO"] = "/#{wrapper.status_code}"
      @exceptions_app.call(env)
    rescue Exception => failsafe_error
      $stderr.puts "Error during failsafe response: #{failsafe_error}\n  #{failsafe_error.backtrace * "\n  "}"
      FAILSAFE_RESPONSE
    end
  end
end
