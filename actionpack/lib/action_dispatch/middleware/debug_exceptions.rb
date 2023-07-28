# frozen_string_literal: true

require "action_dispatch/middleware/exception_wrapper"
require "action_dispatch/routing/inspector"

require "action_view"

module ActionDispatch
  # = Action Dispatch \DebugExceptions
  #
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
      _, headers, body = response = @app.call(env)

      if headers[Constants::X_CASCADE] == "pass"
        body.close if body.respond_to?(:close)
        raise ActionController::RoutingError, "No route matches [#{env['REQUEST_METHOD']}] #{env['PATH_INFO'].inspect}"
      end

      response
    rescue Exception => exception
      request = ActionDispatch::Request.new env
      backtrace_cleaner = request.get_header("action_dispatch.backtrace_cleaner")
      wrapper = ExceptionWrapper.new(backtrace_cleaner, exception)

      invoke_interceptors(request, exception, wrapper)
      raise exception unless wrapper.show?(request)
      render_exception(request, exception, wrapper)
    end

    private
      def invoke_interceptors(request, exception, wrapper)
        @interceptors.each do |interceptor|
          interceptor.call(request, exception)
        rescue Exception
          log_error(request, wrapper)
        end
      end

      def render_exception(request, exception, wrapper)
        log_error(request, wrapper)

        if request.get_header("action_dispatch.show_detailed_exceptions")
          begin
            content_type = request.formats.first
          rescue ActionDispatch::Http::MimeNegotiation::InvalidType
            content_type = Mime[:text]
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
          exception: wrapper.exception_inspect,
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
          # Everything should use the wrapper, but we need to pass
          # `exception` for legacy code.
          exception: wrapper.exception,
          traces: wrapper.traces,
          show_source_idx: wrapper.source_to_show_id,
          trace_to_show: wrapper.trace_to_show,
          routes_inspector: routes_inspector(wrapper),
          source_extracts: wrapper.source_extracts,
        )
      end

      def render(status, body, format)
        [status, { Rack::CONTENT_TYPE => "#{format}; charset=#{Response.default_charset}", Rack::CONTENT_LENGTH => body.bytesize.to_s }, [body]]
      end

      def log_error(request, wrapper)
        logger = logger(request)

        return unless logger
        return if !log_rescued_responses?(request) && wrapper.rescue_response?

        trace = wrapper.exception_trace

        message = []
        message << "  "
        message << "#{wrapper.exception_class_name} (#{wrapper.message}):"
        message.concat(wrapper.annotated_source_code)
        message << "  "
        message.concat(trace)

        log_array(logger, message, request)
      end

      def log_array(logger, lines, request)
        return if lines.empty?

        level = request.get_header("action_dispatch.debug_exception_log_level")

        if logger.formatter && logger.formatter.respond_to?(:tags_text)
          logger.add(level, lines.join("\n#{logger.formatter.tags_text}"))
        else
          logger.add(level, lines.join("\n"))
        end
      end

      def logger(request)
        request.logger || ActionView::Base.logger || stderr_logger
      end

      def stderr_logger
        @stderr_logger ||= ActiveSupport::Logger.new($stderr)
      end

      def routes_inspector(exception)
        if @routes_app.respond_to?(:routes) && (exception.routing_error? || exception.template_error?)
          ActionDispatch::Routing::RoutesInspector.new(@routes_app.routes.routes)
        end
      end

      def api_request?(content_type)
        @response_format == :api && !content_type.html?
      end

      def log_rescued_responses?(request)
        request.get_header("action_dispatch.log_rescued_responses")
      end
  end
end
