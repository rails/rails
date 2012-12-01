require 'action_dispatch/http/request'
require 'action_dispatch/middleware/exception_wrapper'
require 'action_dispatch/middleware/exception_failsafe'

module ActionDispatch
  # This middleware rescues any exception returned by the application
  # and calls ActionDispatch::ExceptionFailsafe app that will wrap it
  # in a format for the end user.
  #
  # Multiple exceptions apps can be passed as parameters on initialization
  # of ShowExceptions. Every time there is an exception, ShowExceptions will
  # store the exception in env["action_dispatch.exception"], rewrite the
  # PATH_INFO to the exception status code and call the rack app.
  #
  # If the application returns a "X-Cascade" pass response, this middleware
  # will send an empty response as result with the correct status code.
  class ShowExceptions
    def initialize(app, exceptions_app)
      @app = app
      @exceptions_app = exceptions_app
    end

    def call(env)
      return @app.call(env)
    rescue Exception => exception
      raise exception if env['action_dispatch.show_exceptions'] == false
      render_exception(env, exception)
    end

    private

    def render_exception(env, exception)
      wrapper = ExceptionWrapper.new(env, exception)
      status  = wrapper.status_code
      env["action_dispatch.exception"] = wrapper.exception
      env["PATH_INFO"] = "/#{status}"
      response = @exceptions_app.call(env)
      response[1]['X-Cascade'] == 'pass' ? pass_response(status) : response
    end

    def pass_response(status)
      [status, {"Content-Type" => "text/html; charset=#{Response.default_charset}", "Content-Length" => "0"}, []]
    end
  end
end
