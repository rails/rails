# frozen_string_literal: true

require "action_dispatch/middleware/exception_wrapper"

module ActionDispatch
  # This middleware rescues any exception returned by the application
  # and calls an exceptions app that will wrap it in a format for the end user.
  #
  # The exceptions app should be passed as a parameter on initialization of
  # +ShowExceptions+. Every time there is an exception, +ShowExceptions+ will
  # store the exception in <tt>env["action_dispatch.exception"]</tt>, rewrite
  # the +PATH_INFO+ to the exception status code and call the Rack app.
  #
  # In \Rails applications, the exceptions app can be configured with
  # +config.exceptions_app+, which defaults to ActionDispatch::PublicExceptions.
  #
  # If the application returns an <tt>"X-Cascade" => "pass"</tt> response, this
  # middleware will send an empty response as a result with the correct status
  # code. If any exception happens inside the exceptions app, this middleware
  # catches the exceptions and returns a failsafe response.
  class ShowExceptions
    def initialize(app, exceptions_app)
      @app = app
      @exceptions_app = exceptions_app
    end

    def call(env)
      request = ActionDispatch::Request.new env
      @app.call(env)
    rescue Exception => exception
      if request.show_exceptions?
        render_exception(request, exception)
      else
        raise exception
      end
    end

    private
      def render_exception(request, exception)
        backtrace_cleaner = request.get_header "action_dispatch.backtrace_cleaner"
        wrapper = ExceptionWrapper.new(backtrace_cleaner, exception)
        status  = wrapper.status_code
        request.set_header "action_dispatch.exception", wrapper.unwrapped_exception
        request.set_header "action_dispatch.original_path", request.path_info
        request.set_header "action_dispatch.original_request_method", request.raw_request_method
        fallback_to_html_format_if_invalid_mime_type(request)
        request.path_info = "/#{status}"
        request.request_method = "GET"
        response = @exceptions_app.call(request.env)
        response[1]["X-Cascade"] == "pass" ? pass_response(status) : response
      rescue Exception => failsafe_error
        $stderr.puts "Error during failsafe response: #{failsafe_error}\n  #{failsafe_error.backtrace * "\n  "}"

        [500, { "Content-Type" => "text/plain" },
          ["500 Internal Server Error\n" \
          "If you are the administrator of this website, then please read this web " \
          "application's log file and/or the web server's log file to find out what " \
          "went wrong."]]
      end

      def fallback_to_html_format_if_invalid_mime_type(request)
        # If the MIME type for the request is invalid then the
        # @exceptions_app may not be able to handle it. To make it
        # easier to handle, we switch to HTML.
        request.formats
      rescue ActionDispatch::Http::MimeNegotiation::InvalidType
        request.set_header "HTTP_ACCEPT", "text/html"
      end

      def pass_response(status)
        [status, { "Content-Type" => "text/html; charset=#{Response.default_charset}", "Content-Length" => "0" }, []]
      end
  end
end
