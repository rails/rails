# frozen_string_literal: true

require "active_support/core_ext/module/attribute_accessors"
require "rack/utils"

module ActionDispatch
  class ExceptionWrapper
    cattr_accessor :rescue_responses, default: Hash.new(:internal_server_error).merge!(
      "ActionController::RoutingError"                     => :not_found,
      "AbstractController::ActionNotFound"                 => :not_found,
      "ActionController::MethodNotAllowed"                 => :method_not_allowed,
      "ActionController::UnknownHttpMethod"                => :method_not_allowed,
      "ActionController::NotImplemented"                   => :not_implemented,
      "ActionController::UnknownFormat"                    => :not_acceptable,
      "ActionDispatch::Http::MimeNegotiation::InvalidType" => :not_acceptable,
      "ActionController::MissingExactTemplate"             => :not_acceptable,
      "ActionController::InvalidAuthenticityToken"         => :unprocessable_entity,
      "ActionController::InvalidCrossOriginRequest"        => :unprocessable_entity,
      "ActionDispatch::Http::Parameters::ParseError"       => :bad_request,
      "ActionController::BadRequest"                       => :bad_request,
      "ActionController::ParameterMissing"                 => :bad_request,
      "Rack::QueryParser::ParameterTypeError"              => :bad_request,
      "Rack::QueryParser::InvalidParameterError"           => :bad_request
    )

    cattr_accessor :rescue_templates, default: Hash.new("diagnostics").merge!(
      "ActionView::MissingTemplate"            => "missing_template",
      "ActionController::RoutingError"         => "routing_error",
      "AbstractController::ActionNotFound"     => "unknown_action",
      "ActiveRecord::StatementInvalid"         => "invalid_statement",
      "ActionView::Template::Error"            => "template_error",
      "ActionController::MissingExactTemplate" => "missing_exact_template",
    )

    cattr_accessor :wrapper_exceptions, default: [
      "ActionView::Template::Error"
    ]

    cattr_accessor :silent_exceptions, default: [
      "ActionController::RoutingError",
      "ActionDispatch::Http::MimeNegotiation::InvalidType"
    ]

    attr_reader :backtrace_cleaner, :exception, :wrapped_causes, :line_number, :file

    def initialize(backtrace_cleaner, exception, editor_url = nil)
      @backtrace_cleaner = backtrace_cleaner
      @exception = exception
      @exception_class_name = @exception.class.name
      @wrapped_causes = wrapped_causes_for(exception, backtrace_cleaner)
      @editor_url = editor_url

      expand_backtrace if exception.is_a?(SyntaxError) || exception.cause.is_a?(SyntaxError)
    end

    def unwrapped_exception
      if wrapper_exceptions.include?(@exception_class_name)
        exception.cause
      else
        exception
      end
    end

    def rescue_template
      @@rescue_templates[@exception_class_name]
    end

    def status_code
      self.class.status_code_for_exception(unwrapped_exception.class.name)
    end

    def exception_trace
      trace = application_trace
      trace = framework_trace if trace.empty? && !silent_exceptions.include?(@exception_class_name)
      trace
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

    def traces
      application_trace_with_ids = []
      framework_trace_with_ids = []
      full_trace_with_ids = []

      full_trace.each_with_index do |trace, idx|
        trace_with_id = {
          exception_object_id: @exception.object_id,
          id: idx,
          trace: trace
        }

        if application_trace.include?(trace)
          application_trace_with_ids << trace_with_id
        else
          framework_trace_with_ids << trace_with_id
        end

        full_trace_with_ids << trace_with_id
      end

      {
        "Application Trace" => application_trace_with_ids,
        "Framework Trace" => framework_trace_with_ids,
        "Full Trace" => full_trace_with_ids
      }
    end

    def self.status_code_for_exception(class_name)
      Rack::Utils.status_code(@@rescue_responses[class_name])
    end

    def source_extracts
      backtrace.map do |trace|
        file, line_number = extract_file_and_line_number(trace)
        editor_url = @editor_url && @editor_url % {
          file: URI.encode_www_form_component(file),
          line: line_number
        }

        {
          code: source_fragment(file, line_number),
          line_number: line_number,
          editor_url: editor_url
        }
      end
    end

    def trace_to_show
      if traces["Application Trace"].empty? && rescue_template != "routing_error"
        "Full Trace"
      else
        "Application Trace"
      end
    end

    def source_to_show_id
      (traces[trace_to_show].first || {})[:id]
    end

    private
      def backtrace
        Array(@exception.backtrace)
      end

      def causes_for(exception)
        return enum_for(__method__, exception) unless block_given?

        yield exception while exception = exception.cause
      end

      def wrapped_causes_for(exception, backtrace_cleaner)
        causes_for(exception).map { |cause| self.class.new(backtrace_cleaner, cause) }
      end

      def clean_backtrace(*args)
        if backtrace_cleaner
          backtrace_cleaner.clean(backtrace, *args)
        else
          backtrace
        end
      end

      def source_fragment(path, line)
        return unless Rails.respond_to?(:root) && Rails.root
        full_path = Rails.root.join(path)
        if File.exist?(full_path)
          File.open(full_path, "r") do |file|
            start = [line - 3, 0].max
            lines = file.each_line.drop(start).take(6)
            Hash[*(start + 1..(lines.count + start)).zip(lines).flatten]
          end
        end
      end

      def extract_file_and_line_number(trace)
        # Split by the first colon followed by some digits, which works for both
        # Windows and Unix path styles.
        file, line = trace.match(/^(.+?):(\d+).*$/, &:captures) || trace
        [file, line.to_i]
      end

      def expand_backtrace
        @exception.backtrace.unshift(
          @exception.to_s.split("\n")
        ).flatten!
      end
  end
end
