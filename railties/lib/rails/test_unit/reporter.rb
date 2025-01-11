# frozen_string_literal: true

require "minitest"

module Rails
  class TestUnitReporter < Minitest::StatisticsReporter
    singleton_class.attr_accessor :app_root

    @executable = "bin/rails test"
    singleton_class.attr_accessor :executable

    def prerecord(test_class, test_name)
      super
      if options[:verbose]
        io.print "%s#%s = " % [test_class.name, test_name]
      end
    end

    def record(result)
      super

      if options[:verbose]
        io.puts color_output(format_line(result), by: result)
      else
        io.print color_output(result.result_code, by: result)
      end

      if output_inline? && result.failure && (!result.skipped? || options[:verbose])
        io.puts
        io.puts
        io.puts color_output(result, by: result)
        io.puts
        io.puts format_rerun_snippet(result)
        io.puts
      end

      if fail_fast? && result.failure && !result.skipped?
        raise Interrupt
      end
    end

    def report
      return if output_inline? || filtered_results.empty?
      io.puts
      io.puts "Failed tests:"
      io.puts
      io.puts aggregated_results
    end

    def aggregated_results # :nodoc:
      filtered_results.map { |result| format_rerun_snippet(result) }.join "\n"
    end

    def filtered_results
      if options[:verbose]
        results
      else
        results.reject(&:skipped?)
      end
    end

    def relative_path_for(file)
      if app_root
        file.sub(/^#{app_root}\/?/, "")
      else
        file
      end
    end

    private
      def output_inline?
        options[:output_inline]
      end

      def fail_fast?
        options[:fail_fast]
      end

      def format_line(result)
        "%.2f s = %s" % [result.time, result.result_code]
      end

      def format_rerun_snippet(result)
        location, line = if result.respond_to?(:source_location)
          result.source_location
        else
          result.method(result.name).source_location
        end

        "#{self.class.executable} #{relative_path_for(location)}:#{line}"
      end

      def app_root
        @app_root ||= self.class.app_root ||
          if defined?(ENGINE_ROOT)
            ENGINE_ROOT
          elsif Rails.respond_to?(:root)
            Rails.root
          end
      end

      def colored_output?
        options[:color] && io.respond_to?(:tty?) && io.tty?
      end

      codes = { red: 31, green: 32, yellow: 33 }
      COLOR_BY_RESULT_CODE = {
        "." => codes[:green],
        "E" => codes[:red],
        "F" => codes[:red],
        "S" => codes[:yellow]
      }

      def color_output(string, by:)
        if colored_output?
          "\e[#{COLOR_BY_RESULT_CODE[by.result_code]}m#{string}\e[0m"
        else
          string
        end
      end
  end
end
