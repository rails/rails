# frozen_string_literal: true

require "active_support/core_ext/enumerable"
require "active_support/syntax_error_proxy"

module ActionView
  # = Action View Errors
  class ActionViewError < StandardError # :nodoc:
  end

  class EncodingError < StandardError # :nodoc:
  end

  class WrongEncodingError < EncodingError # :nodoc:
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

  class StrictLocalsError < ArgumentError # :nodoc:
    def initialize(argument_error, template)
      message = argument_error.message.
                  gsub("unknown keyword:", "unknown local:").
                  gsub("missing keyword:", "missing local:").
                  gsub("no keywords accepted", "no locals accepted").
                  concat(" for #{template.short_identifier}")
      super(message)
    end
  end

  class MissingTemplate < ActionViewError # :nodoc:
    attr_reader :path, :paths, :prefixes, :partial

    def initialize(paths, path, prefixes, partial, details, *)
      if partial && path.present?
        path = path.sub(%r{([^/]+)$}, "_\\1")
      end

      @path = path
      @paths = paths
      @prefixes = Array(prefixes)
      @partial = partial
      template_type = if partial
        "partial"
      elsif /layouts/i.match?(path)
        "layout"
      else
        "template"
      end

      searched_paths = @prefixes.map { |prefix| [prefix, path].join("/") }

      out  = "Missing #{template_type} #{searched_paths.join(", ")} with #{details.inspect}.\n\nSearched in:\n"
      out += paths.compact.map { |p| "  * #{p.to_s.inspect}\n" }.join
      super out
    end

    if defined?(DidYouMean::Correctable) && defined?(DidYouMean::Jaro)
      include DidYouMean::Correctable

      class Results # :nodoc:
        Result = Struct.new(:path, :score)

        def initialize(size)
          @size = size
          @results = []
        end

        def to_a
          @results.map(&:path)
        end

        def should_record?(score)
          if @results.size < @size
            true
          else
            score < @results.last.score
          end
        end

        def add(path, score)
          if should_record?(score)
            @results << Result.new(path, score)
            @results.sort_by!(&:score)
            @results.pop if @results.size > @size
          end
        end
      end

      # Apps may have thousands of candidate templates so we attempt to
      # generate the suggestions as efficiently as possible.
      # First we split templates into prefixes and basenames, so that those can
      # be matched separately.
      def corrections
        candidates = paths.flat_map(&:all_template_paths).uniq

        if partial
          candidates.select!(&:partial?)
        else
          candidates.reject!(&:partial?)
        end

        # Group by possible prefixes
        files_by_dir = candidates.group_by(&:prefix)
        files_by_dir.transform_values! do |files|
          files.map do |file|
            # Remove prefix
            File.basename(file.to_s)
          end
        end

        # No suggestions if there's an exact match, but wrong details
        if prefixes.any? { |prefix| files_by_dir[prefix]&.include?(path) }
          return []
        end

        cached_distance = Hash.new do |h, args|
          h[args] = -DidYouMean::Jaro.distance(*args)
        end

        results = Results.new(6)

        files_by_dir.keys.index_with do |dirname|
          prefixes.map do |prefix|
            cached_distance[[prefix, dirname]]
          end.min
        end.sort_by(&:last).each do |dirname, dirweight|
          # If our directory's score makes it impossible to find a better match
          # we can prune this search branch.
          next unless results.should_record?(dirweight - 1.0)

          files = files_by_dir[dirname]

          files.each do |file|
            fileweight = cached_distance[[path, file]]
            score = dirweight + fileweight

            results.add(File.join(dirname, file), score)
          end
        end

        if partial
          results.to_a.map { |res| res.sub(%r{_([^/]+)\z}, "\\1") }
        else
          results.to_a
        end
      end
    end
  end

  class Template
    # The Template::Error exception is raised when the compilation or rendering of the template
    # fails. This exception then gathers a bunch of intimate details and uses it to report a
    # precise exception message.
    class Error < ActionViewError # :nodoc:
      SOURCE_CODE_RADIUS = 3

      # Override to prevent #cause resetting during re-raise.
      attr_reader :cause

      attr_reader :template

      def initialize(template)
        super($!.message)
        @cause = $!
        if @cause.is_a?(SyntaxError)
          @cause = ActiveSupport::SyntaxErrorProxy.new(@cause)
        end
        @template, @sub_templates = template, nil
      end

      def backtrace
        @cause.backtrace
      end

      def backtrace_locations
        @cause.backtrace_locations
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

  class SyntaxErrorInTemplate < TemplateError # :nodoc:
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
