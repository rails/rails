# frozen_string_literal: true

# :markup: markdown

require "active_support/core_ext/module/attribute_accessors"
require "active_support/syntax_error_proxy"
require "active_support/core_ext/thread/backtrace/location"
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

    attr_reader :backtrace_cleaner, :wrapped_causes, :exception_class_name, :exception

    def initialize(backtrace_cleaner, exception)
      @backtrace_cleaner = backtrace_cleaner
      @exception_class_name = exception.class.name
      @wrapped_causes = wrapped_causes_for(exception, backtrace_cleaner)
      @exception = exception
      if exception.is_a?(SyntaxError)
        @exception = ActiveSupport::SyntaxErrorProxy.new(exception)
      end
      @backtrace = build_backtrace
    end

    def routing_error?
      @exception.is_a?(ActionController::RoutingError)
    end

    def template_error?
      @exception.is_a?(ActionView::Template::Error)
    end

    def sub_template_message
      @exception.sub_template_message
    end

    def has_cause?
      @exception.cause
    end

    def failures
      @exception.failures
    end

    def has_corrections?
      @exception.respond_to?(:original_message) && @exception.respond_to?(:corrections)
    end

    def original_message
      @exception.original_message
    end

    def corrections
      @exception.corrections
    end

    def file_name
      @exception.file_name
    end

    def line_number
      @exception.line_number
    end

    def actions
      ActiveSupport::ActionableError.actions(@exception)
    end

    def unwrapped_exception
      if wrapper_exceptions.include?(@exception_class_name)
        @exception.cause
      else
        @exception
      end
    end

    def annotated_source_code
      if exception.respond_to?(:annotated_source_code)
        exception.annotated_source_code
      else
        []
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

    def show?(request)
      # We're treating `nil` as "unset", and we want the default setting to be `:all`.
      # This logic should be extracted to `env_config` and calculated once.
      config = request.get_header("action_dispatch.show_exceptions")

      case config
      when :none
        false
      when :rescuable
        rescue_response?
      else
        true
      end
    end

    def rescue_response?
      @@rescue_responses.key?(exception.class.name)
    end

    def source_extracts
      backtrace.map do |trace|
        extract_source(trace)
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

    def exception_name
      exception.cause.class.to_s
    end

    def message
      exception.message
    end

    def exception_inspect
      exception.inspect
    end

    def exception_id
      exception.object_id
    end

    private
      class SourceMapLocation < DelegateClass(Thread::Backtrace::Location) # :nodoc:
        def initialize(location, template)
          super(location)
          @template = template
        end

        def spot(exc)
          if RubyVM::AbstractSyntaxTree.respond_to?(:node_id_for_backtrace_location) && __getobj__.is_a?(Thread::Backtrace::Location)
            location = @template.spot(__getobj__)
          else
            location = super
          end

          if location
            @template.translate_location(__getobj__, location)
          end
        end
      end

      attr_reader :backtrace

      def build_backtrace
        built_methods = {}

        ActionView::PathRegistry.all_resolvers.each do |resolver|
          resolver.built_templates.each do |template|
            built_methods[template.method_name] = template
          end
        end

        (@exception.backtrace_locations || []).map do |loc|
          if built_methods.key?(loc.base_label)
            thread_backtrace_location = if loc.respond_to?(:__getobj__)
              loc.__getobj__
            else
              loc
            end
            SourceMapLocation.new(thread_backtrace_location, built_methods[loc.base_label])
          else
            loc
          end
        end
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

      def extract_source(trace)
        spot = trace.spot(@exception)

        if spot
          line = spot[:first_lineno]
          code = extract_source_fragment_lines(spot[:script_lines], line)

          if line == spot[:last_lineno]
            code[line] = [
              code[line][0, spot[:first_column]],
              code[line][spot[:first_column]...spot[:last_column]],
              code[line][spot[:last_column]..-1],
            ]
          end

          return {
            code: code,
            line_number: line
          }
        end

        file, line_number = extract_file_and_line_number(trace)

        {
          code: source_fragment(file, line_number),
          line_number: line_number
        }
      end

      def extract_source_fragment_lines(source_lines, line)
        start = [line - 3, 0].max
        lines = source_lines.drop(start).take(6)
        Hash[*(start + 1..(lines.count + start)).zip(lines).flatten]
      end

      def source_fragment(path, line)
        return unless Rails.respond_to?(:root) && Rails.root
        full_path = Rails.root.join(path)
        if File.exist?(full_path)
          File.open(full_path, "r") do |file|
            extract_source_fragment_lines(file.each_line, line)
          end
        end
      end

      def extract_file_and_line_number(trace)
        [trace.path, trace.lineno]
      end
  end
end
