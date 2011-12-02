require 'action_dispatch/http/request'
require 'action_dispatch/middleware/exception_wrapper'
require 'active_support/deprecation'

module ActionDispatch
  # This middleware rescues any exception returned by the application
  # and wraps them in a format for the end user.
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
        response  = @app.call(env)
      rescue Exception => exception
        raise exception if env['action_dispatch.show_exceptions'] == false
      end

      response ? response : render_exception_with_failsafe(env, exception)
    end

    private

    # Define this method because some plugins were monkey patching it.
    # Remove this after 3.2 is out with the other deprecations in this class.
    def status_code(*)
    end

    def render_exception_with_failsafe(env, exception)
      render_exception(env, exception)
    rescue Exception => failsafe_error
      $stderr.puts "Error during failsafe response: #{failsafe_error}\n  #{failsafe_error.backtrace * "\n  "}"
      FAILSAFE_RESPONSE
    end

    def render_exception(env, exception)
      wrapper = ExceptionWrapper.new(env, exception)

      status      = wrapper.status_code
      locale_path = "#{public_path}/#{status}.#{I18n.locale}.html" if I18n.locale
      path        = "#{public_path}/#{status}.html"

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

    # TODO: Make this a middleware initialization parameter once
    # we removed the second option (which is deprecated)
    def public_path
      defined?(Rails.public_path) ? Rails.public_path : 'public_path'
    end
  end
end
