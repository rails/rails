# frozen_string_literal: true

module Rails
  class CodeStatisticsCalculator # :nodoc:
    attr_reader :lines, :code_lines, :classes, :methods

    PATTERNS = {
      rb: {
        line_comment: /^\s*#/,
        begin_block_comment: /^=begin/,
        end_block_comment: /^=end/,
        class: /^\s*class\s+[_A-Z]/,
        method: /^\s*def\s+[_a-z]/,
      },
      erb: {
        line_comment: %r{((^\s*<%#.*%>)|(<!--.*-->))},
      },
      css: {
        line_comment: %r{^\s*/\*.*\*/},
      },
      scss: {
        line_comment: %r{((^\s*/\*.*\*/)|(^\s*//))},
      },
      js: {
        line_comment: %r{^\s*//},
        begin_block_comment: %r{^\s*/\*},
        end_block_comment: %r{\*/},
        method: /function(\s+[_a-zA-Z][\da-zA-Z]*)?\s*\(/,
      },
      coffee: {
        line_comment: /^\s*#/,
        begin_block_comment: /^\s*###/,
        end_block_comment: /^\s*###/,
        class: /^\s*class\s+[_A-Z]/,
        method: /[-=]>/,
      }
    }

    PATTERNS[:minitest] = PATTERNS[:rb].merge method: /^\s*(def|test)\s+['"_a-z]/
    PATTERNS[:rake] = PATTERNS[:rb]

    def initialize(lines = 0, code_lines = 0, classes = 0, methods = 0)
      @lines = lines
      @code_lines = code_lines
      @classes = classes
      @methods = methods
    end

    def add(code_statistics_calculator)
      @lines += code_statistics_calculator.lines
      @code_lines += code_statistics_calculator.code_lines
      @classes += code_statistics_calculator.classes
      @methods += code_statistics_calculator.methods
    end

    def add_by_file_path(file_path)
      File.open(file_path) do |f|
        add_by_io(f, file_type(file_path))
      end
    end

    def add_by_io(io, file_type)
      patterns = PATTERNS[file_type] || {}

      comment_started = false

      while line = io.gets
        @lines += 1

        if comment_started
          if patterns[:end_block_comment] && patterns[:end_block_comment].match?(line)
            comment_started = false
          end
          next
        else
          if patterns[:begin_block_comment] && patterns[:begin_block_comment].match?(line)
            comment_started = true
            next
          end
        end

        @classes   += 1 if patterns[:class] && patterns[:class].match?(line)
        @methods   += 1 if patterns[:method] && patterns[:method].match?(line)
        if !line.match?(/^\s*$/) && (patterns[:line_comment].nil? || !line.match?(patterns[:line_comment]))
          @code_lines += 1
        end
      end
    end

    private
      def file_type(file_path)
        if file_path.end_with? "_test.rb"
          :minitest
        else
          File.extname(file_path).delete_prefix(".").downcase.to_sym
        end
      end
  end
end
