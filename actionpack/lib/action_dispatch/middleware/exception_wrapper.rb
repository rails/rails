require 'action_controller/metal/exceptions'
require 'active_support/core_ext/module/attribute_accessors'

module ActionDispatch
  class ExceptionWrapper
    cattr_accessor :rescue_responses
    @@rescue_responses = Hash.new(:internal_server_error)
    @@rescue_responses.merge!(
      'ActionController::RoutingError'             => :not_found,
      'AbstractController::ActionNotFound'         => :not_found,
      'ActionController::MethodNotAllowed'         => :method_not_allowed,
      'ActionController::UnknownHttpMethod'        => :method_not_allowed,
      'ActionController::NotImplemented'           => :not_implemented,
      'ActionController::UnknownFormat'            => :not_acceptable,
      'ActionController::InvalidAuthenticityToken' => :unprocessable_entity,
      'ActionDispatch::ParamsParser::ParseError'   => :unprocessable_entity,
      'ActionController::BadRequest'               => :bad_request,
      'ActionController::ParameterMissing'         => :bad_request
    )

    cattr_accessor :rescue_templates
    @@rescue_templates = Hash.new('diagnostics')
    @@rescue_templates.merge!(
      'ActionView::MissingTemplate'         => 'missing_template',
      'ActionController::RoutingError'      => 'routing_error',
      'AbstractController::ActionNotFound'  => 'unknown_action',
      'ActionView::Template::Error'         => 'template_error'
    )

    attr_reader :env, :exception, :line_number, :file

    def initialize(env, exception)
      @env = env
      @exception = original_exception(exception)

      expand_backtrace if exception.is_a?(SyntaxError) || exception.try(:original_exception).try(:is_a?, SyntaxError)
    end

    def rescue_template
      @@rescue_templates[@exception.class.name]
    end

    def status_code
      self.class.status_code_for_exception(@exception.class.name)
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

    def self.status_code_for_exception(class_name)
      Rack::Utils.status_code(@@rescue_responses[class_name])
    end

    def source_extract
      exception.backtrace.map do |trace|
        file, line = trace.split(":")
        line_number = line.to_i
        {
          code: source_fragment(file, line_number),
          file: file,
          line_number: line_number
        }
      end if exception.backtrace
    end

    private

    def original_exception(exception)
      if registered_original_exception?(exception)
        exception.original_exception
      else
        exception
      end
    end

    def registered_original_exception?(exception)
      exception.respond_to?(:original_exception) && @@rescue_responses.has_key?(exception.original_exception.class.name)
    end

    def clean_backtrace(*args)
      if backtrace_cleaner
        backtrace_cleaner.clean(@exception.backtrace, *args)
      else
        @exception.backtrace
      end
    end

    def backtrace_cleaner
      @backtrace_cleaner ||= @env['action_dispatch.backtrace_cleaner']
    end

    def source_fragment(path, line)
      return unless Rails.respond_to?(:root) && Rails.root
      full_path = Rails.root.join(path)
      if File.exist?(full_path)
        File.open(full_path, "r") do |file|
          start = [line - 3, 0].max
          lines = file.each_line.drop(start).take(6)
          Hash[*(start+1..(lines.count+start)).zip(lines).flatten]
        end
      end
    end

    def expand_backtrace
      @exception.backtrace.unshift(
        @exception.to_s.split("\n")
      ).flatten!
    end
  end
end
