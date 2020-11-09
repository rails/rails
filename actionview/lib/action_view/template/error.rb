# frozen_string_literal: true

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
      @string.force_encoding(Encoding::ASCII_8BIT)
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
      prefixes = Array(prefixes)
      template_type = if partial
        "partial"
      elsif /layouts/i.match?(path)
        "layout"
      else
        "template"
      end

      if partial && path.present?
        path = path.sub(%r{([^/]+)$}, "_\\1")
      end
      searched_paths = prefixes.map { |prefix| [prefix, path].join("/") }

      out  = "Missing #{template_type} #{searched_paths.join(", ")} with #{details.inspect}. Searched in:\n"
      out += paths.compact.map { |p| "  * #{p.to_s.inspect}\n" }.join
      super out
    end
  end

  class Template
    # The Template::Error exception is raised when the compilation or rendering of the template
    # fails. This exception then gathers a list of the function calls that were active in the thread and uses it to report a
    # precise exception message.
    class Error < ActionViewError #:nodoc:
      SOURCE_CODE_RADIUS = 3

      # Override to prevent #cause resetting during re-raise.
      attr_reader :cause

      def initialize(template)
        super($!.message)
        set_backtrace($!.backtrace)
        @cause = $!
        @template, @sub_templates = template, nil
      end

      def file_name
        @template.identifier
      end

      def sub_template_message
        if @sub_templates
          "Trace of template inclusion: " +
          @sub_templates.collect(&:inspect).join(", ")
        else
          ""
        end
      end

      def source_extract(indentation = 0)
        return [] unless num = line_number
        num = num.to_i

        source_code = @template.encode!.split("\n")

        start_on_line = [ num - SOURCE_CODE_RADIUS - 1, 0 ].max
        end_on_line   = [ num + SOURCE_CODE_RADIUS - 1, source_code.length].min

        indent = end_on_line.to_s.size + indentation
        return [] unless source_code = source_code[start_on_line..end_on_line]

        formatted_code_for(source_code, start_on_line, indent)
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

      def annotated_source_code
        source_extract(4)
      end

      private
        def source_location
          if line_number
            "on line ##{line_number} of "
          else
            "in "
          end + file_name
        end

        def formatted_code_for(source_code, line_counter, indent)
          indent_template = "%#{indent}s: %s"
          source_code.map do |line|
            line_counter += 1
            indent_template % [line_counter, line]
          end
        end
    end
  end

  TemplateError = Template::Error

  class SyntaxErrorInTemplate < TemplateError #:nodoc
    def initialize(template, offending_code_string)
      @offending_code_string = offending_code_string
      super(template)
    end

    def message
      <<~MESSAGE
        Encountered a syntax error while rendering template: check #{@offending_code_string}
      MESSAGE
    end

    def annotated_source_code
      @offending_code_string.split("\n").map.with_index(1) { |line, index|
        indentation = " " * 4
        "#{index}:#{indentation}#{line}"
      }
    end
  end
end
