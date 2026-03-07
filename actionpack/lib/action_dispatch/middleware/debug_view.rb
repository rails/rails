# frozen_string_literal: true

# :markup: markdown

require "pp"

require "action_view"
require "action_view/base"

module ActionDispatch
  class DebugView < ActionView::Base # :nodoc:
    RESCUES_TEMPLATE_PATHS = [File.expand_path("templates", __dir__)]
    HOST_APP_PATH = ENV["RAILS_HOST_APP_PATH"]

    def initialize(assigns)
      paths = RESCUES_TEMPLATE_PATHS.dup
      lookup_context = ActionView::LookupContext.new(paths)
      super(lookup_context, assigns, nil)
    end

    def compiled_method_container
      self.class
    end

    def debug_params(params)
      clean_params = params.clone
      clean_params.delete("action")
      clean_params.delete("controller")

      if clean_params.empty?
        "None"
      else
        PP.pp(clean_params, +"", 200)
      end
    end

    def debug_headers(headers)
      if headers.present?
        headers.inspect.gsub(",", ",\n")
      else
        "None"
      end
    end

    def debug_hash(object)
      object.to_hash.sort_by { |k, _| k.to_s }.map { |k, v| "#{k}: #{v.inspect rescue $!.message}" }.join("\n")
    end

    def ai_prompt_title
      "Prompt for AI agents"
    end

    def ai_prompt_text
      lines = []
      wrapper = @exception_wrapper

      if wrapper.nil?
        lines << "Issue summary:"
        lines << "- Exception: (unavailable)"
        lines << "- Request: (unavailable)"
        lines << "Task for the AI agent:"
        lines << "1) Explain the likely root cause in plain language."
        lines << "2) Suggest a fix with file and line references."
        lines << "3) Call out tests to add or update."
        return lines.join("\n")
      end

      lines << "Issue summary:"
      lines << "- Exception: #{wrapper.exception_class_name}: #{wrapper.message}"
      request_method = begin
        @request.request_method
      rescue StandardError
        "UNKNOWN"
      end
      lines << "- Request: #{request_method} #{@request.fullpath}"

      if params_valid? && @request.parameters["controller"]
        action = @request.parameters["action"]
        controller = @request.parameters["controller"]
        lines << "- Controller/action: #{controller}##{action}"
      end

      if params_valid?
        lines << "Parameters (filtered):"
        debug_params(@request.filtered_parameters).each_line do |line|
          lines << "  #{line.rstrip}"
        end
      end

      rails_version = defined?(Rails) && Rails.respond_to?(:version) ? Rails.version : "unknown"
      rails_env = defined?(Rails) && Rails.respond_to?(:env) ? Rails.env : "unknown"
      lines << "Environment:"
      lines << "  Rails #{rails_version} on Ruby #{RUBY_VERSION} (#{rails_env})"

      trace = wrapper.exception_trace.map(&:to_s)
      trace = trace.first(5)
      lines << "Relevant backtrace:"
      if trace.empty?
        lines << "  (no backtrace available)"
      else
        trace.each { |entry| lines << "  #{entry}" }
      end

      lines << "Task for the AI agent:"
      lines << "1) Explain the likely root cause in plain language."
      lines << "2) Suggest a fix with file and line references."
      lines << "3) Call out tests to add or update."

      lines.join("\n")
    end

    def render(*)
      logger = ActionView::Base.logger

      if logger && logger.respond_to?(:silence)
        logger.silence { super }
      else
        super
      end
    end

    def editor_url(location, line: nil)
      if editor = ActiveSupport::Editor.current
        line ||= location&.lineno
        absolute_path = location&.absolute_path

        if absolute_path && line && File.exist?(absolute_path)
          editor.url_for(translate_path_for_editor(absolute_path), line)
        end
      end
    end

    def protect_against_forgery?
      false
    end

    def params_valid?
      @request.parameters
    rescue ActionController::BadRequest
      false
    end

    private
      def translate_path_for_editor(absolute_path)
        path = absolute_path.to_s
        return path if HOST_APP_PATH.blank?
        return path unless defined?(Rails) && Rails.respond_to?(:root) && Rails.root

        app_root = Rails.root.to_s

        prefix = app_root.end_with?(File::SEPARATOR) ? app_root : "#{app_root}#{File::SEPARATOR}"
        return path unless path.start_with?(prefix)

        relative = path.delete_prefix(prefix)

        File.join(HOST_APP_PATH, relative)
      end
  end
end
