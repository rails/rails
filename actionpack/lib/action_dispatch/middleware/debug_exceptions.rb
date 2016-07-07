require 'action_dispatch/http/request'
require 'action_dispatch/middleware/exception_wrapper'
require 'action_dispatch/routing/inspector'
require 'action_view'
require 'action_view/base'

require 'pp'

module ActionDispatch
  # This middleware is responsible for logging exceptions and
  # showing a debugging page in case the request is local.
  class DebugExceptions
    RESCUES_TEMPLATE_PATH = File.expand_path('../templates', __FILE__)

    class DebugView < ActionView::Base
      def debug_params(params)
        clean_params = params.clone
        clean_params.delete("action")
        clean_params.delete("controller")

        if clean_params.empty?
          'None'
        else
          PP.pp(clean_params, "", 200)
        end
      end

      def debug_headers(headers)
        if headers.present?
          headers.inspect.gsub(',', ",\n")
        else
          'None'
        end
      end

      def debug_hash(object)
        object.to_hash.sort_by { |k, _| k.to_s }.map { |k, v| "#{k}: #{v.inspect rescue $!.message}" }.join("\n")
      end
    end

    def initialize(app, routes_app = nil, response_format = :default)
      @app             = app
      @routes_app      = routes_app
      @response_format = response_format
    end

    def call(env)
      request = ActionDispatch::Request.new env
      _, headers, body = response = @app.call(env)

      if headers['X-Cascade'] == 'pass'
        body.close if body.respond_to?(:close)
        raise ActionController::RoutingError, "No route matches [#{env['REQUEST_METHOD']}] #{env['PATH_INFO'].inspect}"
      end

      response
    rescue Exception => exception
      raise exception unless request.show_exceptions?
      render_exception(request, exception)
    end

    private

    def render_exception(request, exception)
      backtrace_cleaner = request.get_header('action_dispatch.backtrace_cleaner')
      wrapper = ExceptionWrapper.new(backtrace_cleaner, exception)
      log_error(request, wrapper)

      if request.get_header('action_dispatch.show_detailed_exceptions')
        case @response_format
        when :api
          render_for_api_application(request, wrapper)
        when :default
          render_for_default_application(request, wrapper)
        end
      else
        raise exception
      end
    end

    def render_for_default_application(request, wrapper)
      template = create_template(request, wrapper)
      file = "rescues/#{wrapper.rescue_template}"

      if request.xhr?
        body = template.render(template: file, layout: false, formats: [:text])
        format = "text/plain"
      else
        body = template.render(template: file, layout: 'rescues/layout')
        format = "text/html"
      end
      render(wrapper.status_code, body, format)
    end

    def render_for_api_application(request, wrapper)
      body = {
        status: wrapper.status_code,
        error:  Rack::Utils::HTTP_STATUS_CODES.fetch(
          wrapper.status_code,
          Rack::Utils::HTTP_STATUS_CODES[500]
        ),
        exception: wrapper.exception.inspect,
        traces: wrapper.traces
      }

      content_type = request.formats.first
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
      traces = wrapper.traces

      trace_to_show = 'Application Trace'
      if traces[trace_to_show].empty? && wrapper.rescue_template != 'routing_error'
        trace_to_show = 'Full Trace'
      end

      if source_to_show = traces[trace_to_show].first
        source_to_show_id = source_to_show[:id]
      end

      DebugView.new([RESCUES_TEMPLATE_PATH],
        request: request,
        exception: wrapper.exception,
        traces: traces,
        show_source_idx: source_to_show_id,
        trace_to_show: trace_to_show,
        routes_inspector: routes_inspector(wrapper.exception),
        source_extracts: wrapper.source_extracts,
        line_number: wrapper.line_number,
        file: wrapper.file
      )
    end

    def render(status, body, format)
      [status, {'Content-Type' => "#{format}; charset=#{Response.default_charset}", 'Content-Length' => body.bytesize.to_s}, [body]]
    end

    def log_error(request, wrapper)
      logger = logger(request)
      return unless logger

      exception = wrapper.exception

      trace = wrapper.application_trace
      trace = wrapper.framework_trace if trace.empty?

      ActiveSupport::Deprecation.silence do
        logger.fatal "  "
        logger.fatal "#{exception.class} (#{exception.message}):"
        log_array logger, exception.annoted_source_code if exception.respond_to?(:annoted_source_code)
        logger.fatal "  "
        log_array logger, trace
      end
    end

    def log_array(logger, array)
      array.map { |line| logger.fatal line }
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
  end
end
