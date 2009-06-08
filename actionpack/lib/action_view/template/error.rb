require "active_support/core_ext/enumerable"

module ActionView
  # The TemplateError exception is raised when the compilation of the template fails. This exception then gathers a
  # bunch of intimate details and uses it to report a very precise exception message.
  class TemplateError < ActionViewError #:nodoc:
    SOURCE_CODE_RADIUS = 3

    attr_reader :original_exception

    def initialize(template, assigns, original_exception)
      @template, @assigns, @original_exception = template, assigns.dup, original_exception
      @backtrace = compute_backtrace
    end

    def file_name
      @template.identifier
    end

    def message
      ActiveSupport::Deprecation.silence { original_exception.message }
    end

    def clean_backtrace
      if defined?(Rails) && Rails.respond_to?(:backtrace_cleaner)
        Rails.backtrace_cleaner.clean(original_exception.backtrace)
      else
        original_exception.backtrace
      end
    end

    def sub_template_message
      if @sub_templates
        "Trace of template inclusion: " +
        @sub_templates.collect { |template| template.identifier }.join(", ")
      else
        ""
      end
    end

    def source_extract(indentation = 0)
      return unless num = line_number
      num = num.to_i

      source_code = @template.source.split("\n")

      start_on_line = [ num - SOURCE_CODE_RADIUS - 1, 0 ].max
      end_on_line   = [ num + SOURCE_CODE_RADIUS - 1, source_code.length].min

      indent = ' ' * indentation
      line_counter = start_on_line
      return unless source_code = source_code[start_on_line..end_on_line]

      source_code.sum do |line|
        line_counter += 1
        "#{indent}#{line_counter}: #{line}\n"
      end
    end

    def sub_template_of(template_path)
      @sub_templates ||= []
      @sub_templates << template_path
    end

    def line_number
      @line_number ||=
        if file_name
          regexp = /#{Regexp.escape File.basename(file_name)}:(\d+)/

          $1 if message =~ regexp or clean_backtrace.find { |line| line =~ regexp }
        end
    end

    def to_s
      "\n#{self.class} (#{message}) #{source_location}:\n" + 
      "#{source_extract}\n    #{clean_backtrace.join("\n    ")}\n\n"
    end

    # don't do anything nontrivial here. Any raised exception from here becomes fatal 
    # (and can't be rescued).
    def backtrace
      @backtrace
    end

    private
      def compute_backtrace
        [
          "#{source_location.capitalize}\n\n#{source_extract(4)}\n    " +
          clean_backtrace.join("\n    ")
        ]
      end

      def source_location
        if line_number
          "on line ##{line_number} of "
        else
          'in '
        end + file_name
      end
  end
end