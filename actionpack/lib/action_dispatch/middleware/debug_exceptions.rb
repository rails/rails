# frozen_string_literal: true

require "action_dispatch/http/request"
require "action_dispatch/middleware/exception_wrapper"
require "action_dispatch/routing/inspector"

require "active_support/actionable_error"

require "action_view"
require "action_view/base"

module ActionDispatch
  # This middleware is responsible for logging exceptions and
  # showing a debugging page in case the request is local.
  class DebugExceptions
    cattr_reader :interceptors, instance_accessor: false, default: []

    def self.register_interceptor(object = nil, &block)
      interceptor = object || block
      interceptors << interceptor
    end

    def initialize(app, routes_app = nil, response_format = :default, interceptors = self.class.interceptors)
      @app             = app
      @routes_app      = routes_app
      @response_format = response_format
      @interceptors    = interceptors
    end

    def call(env)
      request = ActionDispatch::Request.new env
      _, headers, body = response = @app.call(env)

      if headers["X-Cascade"] == "pass"
        body.close if body.respond_to?(:close)
        raise ActionController::RoutingError, "No route matches [#{env['REQUEST_METHOD']}] #{env['PATH_INFO'].inspect}"
      end

      response
    rescue Exception => exception
      invoke_interceptors(request, exception)
      raise exception unless request.show_exceptions?
      render_exception(request, exception)
    end

    private
      def invoke_interceptors(request, exception)
        backtrace_cleaner = request.get_header("action_dispatch.backtrace_cleaner")
        wrapper = ExceptionWrapper.new(backtrace_cleaner, exception)

        @interceptors.each do |interceptor|
          interceptor.call(request, exception)
        rescue Exception
          log_error(request, wrapper)
        end
      end

      def render_exception(request, exception)
        backtrace_cleaner = request.get_header("action_dispatch.backtrace_cleaner")
        wrapper = ExceptionWrapper.new(backtrace_cleaner, exception)
        log_error(request, wrapper)

        if request.get_header("action_dispatch.show_detailed_exceptions")
          begin
            content_type = request.formats.first
          rescue Mime::Type::InvalidMimeType
            render_for_api_request(Mime[:text], wrapper)
          end

          if api_request?(content_type)
            render_for_api_request(content_type, wrapper)
          else
            render_for_browser_request(request, wrapper)
          end
        else
          raise exception
        end
      end

      def render_for_browser_request(request, wrapper)
        template = create_template(request, wrapper)
        file = "rescues/#{wrapper.rescue_template}"

        if request.xhr?
          body = template.render(template: file, layout: false, formats: [:text])
          format = "text/plain"
        else
          body = template.render(template: file, layout: "rescues/layout")
          format = "text/html"
        end
        render(wrapper.status_code, body, format)
      end

      def render_for_api_request(content_type, wrapper)
        body = {
          status: wrapper.status_code,
          error:  Rack::Utils::HTTP_STATUS_CODES.fetch(
            wrapper.status_code,
            Rack::Utils::HTTP_STATUS_CODES[500]
          ),
          exception: wrapper.exception.inspect,
          traces: wrapper.traces
        }

        to_format = "to_#{content_type.to_sym}"

        if content_type && body.respond_to?(to_format)
          formatted_body = body.public_send(to_format)
          format = content_type
        else
          formatted_body = body.to_json
          format = Mime[:json]
        end

        render(wrapper.status_code, formatted_body, format)
      end

      def create_template(request, wrapper)
        DebugView.new(
          request: request,
          exception_wrapper: wrapper,
          exception: wrapper.exception,
          traces: wrapper.traces,
          show_source_idx: wrapper.source_to_show_id,
          trace_to_show: wrapper.trace_to_show,
          routes_inspector: routes_inspector(wrapper.exception),
          source_extracts: wrapper.source_extracts,
          line_number: wrapper.line_number,
          file: wrapper.file
        )
      end

      def render(status, body, format)
        [status, { "Content-Type" => "#{format}; charset=#{Response.default_charset}", "Content-Length" => body.bytesize.to_s }, [body]]
      end

      def log_error(request, wrapper)
        logger = logger(request)

        return unless logger

        exception = wrapper.exception

        trace = wrapper.application_trace
        trace = wrapper.framework_trace if trace.empty?

        ActiveSupport::Deprecation.silence do
          message = []
          message << "  "
          message << "#{exception.class} (#{exception.message}):"
          message.concat(exception.annotated_source_code) if exception.respond_to?(:annotated_source_code)
          message << "  "
          message.concat(trace)

          log_array(logger, message)
        end
      end

      def log_array(logger, array)
        lines = Array(array)

        return if lines.empty?

        if logger.formatter && logger.formatter.respond_to?(:tags_text)
          logger.fatal lines.join("\n#{logger.formatter.tags_text}")
        else
          logger.fatal lines.join("\n")
        end
      end

      def logger(request)
        request.logger || ActionView::Base.logger || stderr_logger
      end

      def stderr_logger
        @stderr_logger ||= ActiveSupport::Logger.new($stderr)
      end

      def routes_inspector(exception)
        if @routes_app.respond_to?(:routes) && (exception.is_a?(ActionController::RoutingError) || exception.is_a?(ActionView::Template::Error))
          ActionDispatch::Routing::RoutesInspector.new(@routes_app.routes.routes)
        end
      end

      def api_request?(content_type)
        @response_format == :api && !content_type.html?
      end
  end
end
