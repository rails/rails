require "active_support/core_ext/array/wrap"
require "active_support/core_ext/enumerable"

module ActionView
  # = Action View Errors
  class ActionViewError < StandardError #:nodoc:
  end

  class EncodingError < StandardError #:nodoc:
  end

  class WrongEncodingError < EncodingError #:nodoc:
    def initialize(string, encoding)
      @string, @encoding = string, encoding
    end

    def message
      @string.force_encoding("BINARY")
      "Your template was not saved as valid #{@encoding}. Please " \
      "either specify #{@encoding} as the encoding for your template " \
      "in your text editor, or mark the template with its " \
      "encoding by inserting the following as the first line " \
      "of the template:\n\n# encoding: <name of correct encoding>.\n\n" \
      "The source of your template was:\n\n#{@string}"
    end
  end

  class MissingTemplate < ActionViewError #:nodoc:
    attr_reader :path

    def initialize(paths, path, prefixes, partial, details, *)
      @path = path
      prefixes = Array.wrap(prefixes)
      template_type = if partial
        "partial"
      elsif path =~ /layouts/i
        'layout'
      else
        'template'
      end

      searched_paths = prefixes.map { |prefix| [prefix, path].join("/") }

      out  = "Missing #{template_type} #{searched_paths.join(", ")} with #{details.inspect}. Searched in:\n"
      out += paths.compact.map { |p| "  * #{p.to_s.inspect}\n" }.join
      super out
    end
  end

  class Template
    # The Template::Error exception is raised when the compilation or rendering of the template
    # fails. This exception then gathers a bunch of intimate details and uses it to report a
    # precise exception message.
    class Error < ActionViewError #:nodoc:
      SOURCE_CODE_RADIUS = 3

      attr_reader :original_exception, :backtrace

      def initialize(template, assigns, original_exception)
        @template, @assigns, @original_exception = template, assigns.dup, original_exception
        @sub_templates = nil
        @backtrace = original_exception.backtrace
      end

      def file_name
        @template.identifier
      end

      def message
        original_exception.message
      end

      def sub_template_message
        if @sub_templates
          "Trace of template inclusion: " +
          @sub_templates.collect { |template| template.inspect }.join(", ")
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
            $1 if message =~ regexp || backtrace.find { |line| line =~ regexp }
          end
      end

      def annoted_source_code
        source_extract(4)
      end

      private

        def source_location
          if line_number
            "on line ##{line_number} of "
          else
            'in '
          end + file_name
        end
    end
  end

  TemplateError = Template::Error
end
