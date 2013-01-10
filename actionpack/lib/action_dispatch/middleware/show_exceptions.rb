require 'action_dispatch/http/request'
require 'action_dispatch/middleware/exception_wrapper'

module ActionDispatch
  # This middleware rescues any exception returned by the application
  # and calls an exceptions app that will wrap it in a format for the end user.
  # Multiple exception apps can be specified, in case there is an error in one
  # of the apps, the first app with a valid response will be used.
  #
  # The exceptions app should be passed as parameter on initialization
  # of ShowExceptions. Every time there is an exception, ShowExceptions will
  # store the exception in env["action_dispatch.exception"], rewrite the
  # PATH_INFO to the exception status code and call the rack app.
  #
  # If the application returns a "X-Cascade" pass response, this middleware
  # will send an empty response as result with the correct status code.
  # If an exception happens inside the all the exceptions apps, this middleware
  # catches the exception and returns a FAILSAFE_RESPONSE.
  class ShowExceptions
    FAILSAFE_RESPONSE = [500, { 'Content-Type' => 'text/plain' },
      ["500 Internal Server Error\n" \
       "If you are the administrator of this website, then please read this web " \
       "application's log file and/or the web server's log file to find out what " \
       "went wrong."]]

    def initialize(app, *exception_apps)
      @app = app
      @exception_apps = exception_apps.flatten.compact.uniq
    end

    def call(env)
      @app.call(env)
    rescue Exception => exception
      raise exception if env['action_dispatch.show_exceptions'] == false
      render_exception(env, exception)
    end

    private

    def name_for_app(app)
      if app.is_a? ActionDispatch::PublicExceptions
        "static error pages from public dir (#{app.class.name})"
      elsif app.is_a? ActionDispatch::Routing::RouteSet
        "action specified in routes (#{app.class.name})"
      else
        "middleware (#{app.class.name})"
      end
    end

    def render_exception(env, exception)
      wrapper = ExceptionWrapper.new(env, exception)
      status  = wrapper.status_code
      env["action_dispatch.exception"] = wrapper.exception
      env["PATH_INFO"] = "/#{status}"
      response = nil

      # iterate over each exception app, store for first valid response
      @exception_apps.each do |exception_app|
        begin
          $stdout.puts "Rendering exception status: #{status} with #{name_for_app(exception_app)}"
          response ||= exception_app.call(env)
        rescue Exception => rescue_error
          $stderr.puts "Error rendering exception #{status} with #{name_for_app(exception_app)}: #{rescue_error}\n  #{rescue_error.backtrace * "\n  "}"
        end
      end

      if response
        response[1]['X-Cascade'] == 'pass' ? pass_response(status) : response
      else
        FAILSAFE_RESPONSE
      end
    end

    def pass_response(status)
      [status, {"Content-Type" => "text/html; charset=#{Response.default_charset}", "Content-Length" => "0"}, []]
    end
  end
end
