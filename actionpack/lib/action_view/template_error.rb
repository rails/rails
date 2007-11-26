module ActionView
  # The TemplateError exception is raised when the compilation of the template fails. This exception then gathers a
  # bunch of intimate details and uses it to report a very precise exception message.
  class TemplateError < ActionViewError #:nodoc:
    SOURCE_CODE_RADIUS = 3

    attr_reader :original_exception

    def initialize(base_path, file_path, assigns, source, original_exception)
      @base_path, @assigns, @source, @original_exception =
        base_path, assigns.dup, source, original_exception
      @file_path = file_path
    end

    def message
      ActiveSupport::Deprecation.silence { original_exception.message }
    end

    def clean_backtrace
      original_exception.clean_backtrace
    end

    def sub_template_message
      if @sub_templates
        "Trace of template inclusion: " +
        @sub_templates.collect { |template| strip_base_path(template) }.join(", ")
      else
        ""
      end
    end

    def source_extract(indentation = 0)
      return unless num = line_number
      num = num.to_i

      source_code = IO.readlines(@file_path)

      start_on_line = [ num - SOURCE_CODE_RADIUS - 1, 0 ].max
      end_on_line   = [ num + SOURCE_CODE_RADIUS - 1, source_code.length].min

      indent = ' ' * indentation
      line_counter = start_on_line

      source_code[start_on_line..end_on_line].sum do |line|
        line_counter += 1
        "#{indent}#{line_counter}: #{line}"
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

    def file_name
      stripped = strip_base_path(@file_path)
      stripped.slice!(0,1) if stripped[0] == ?/
      stripped
    end

    def to_s
      "\n\n#{self.class} (#{message}) #{source_location}:\n" +
        "#{source_extract}\n    #{clean_backtrace.join("\n    ")}\n\n"
    end

    def backtrace
      [
        "#{source_location.capitalize}\n\n#{source_extract(4)}\n    " +
        clean_backtrace.join("\n    ")
      ]
    end

    private
      def strip_base_path(path)
        stripped_path = File.expand_path(path).gsub(@base_path, "")
        stripped_path.gsub!(/^#{Regexp.escape File.expand_path(RAILS_ROOT)}/, '') if defined?(RAILS_ROOT)
        stripped_path
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

if defined?(Exception::TraceSubstitutions)
  Exception::TraceSubstitutions << [/:in\s+`_run_(html|xml).*'\s*$/, '']
  Exception::TraceSubstitutions << [%r{^\s*#{Regexp.escape RAILS_ROOT}/}, ''] if defined?(RAILS_ROOT)
end
