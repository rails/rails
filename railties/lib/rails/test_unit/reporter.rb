require "minitest"

module Rails
  class TestUnitReporter < Minitest::StatisticsReporter
    def report
      return if passed?
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
          "bin/rails test #{failure.location}\n"
        }.join "\n"
      end.join
    end
  end
end
