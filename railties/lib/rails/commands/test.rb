require "method_source"
require 'minitest'

module Rails
  class TestReporter < Minitest::StatisticsReporter
    def report
      io.puts
      io.puts "Failed test:"
      io.puts
      io.puts aggregated_results
    end

    def aggregated_results # :nodoc:
      filtered_results = results.dup
      filtered_results.reject!(&:skipped?) unless options[:verbose]
      filtered_results.map do |result|
        result.failures.map { |failure|
          "rails test #{failure.location}\n"
        }.join "\n"
      end.join
    end
  end

  def Minitest.plugin_rails_init(options)
    self.reporter << TestReporter.new(options[:io], options)
    if method = Rails::TestRunner.find_method
      options[:filter] = "/^(#{method})$/"
    end
  end
  Minitest.extensions << 'rails'

  class TestRunner
    class << self
      def run(filename)
        @filename, @line = filename.split(':')
        $LOAD_PATH.unshift("test")
        load @filename

        Minitest.autorun
      end

      def running?
        !!@filename
      end

      def find_method
        return unless @line
        method = test_methods.find do |test_method, start_line, end_line|
          (start_line..end_line).include?(@line.to_i)
        end
        method.first if method
      end

      def test_methods
        methods_map = []
        suites = Minitest::Runnable.runnables.shuffle
        suites.each do |suite_class|
          suite_class.runnable_methods.each do |test_method|
            method = suite_class.instance_method(test_method)
            start_line = method.source_location.last
            end_line = method.source.split("\n").size + start_line - 1
            methods_map << [test_method, start_line, end_line]
          end
        end
        methods_map
      end
    end
  end
end
