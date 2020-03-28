# frozen_string_literal: true

require "generators/generators_test_helper"
require "rails/generators/rails/benchmark/benchmark_generator"

module Rails
  module Generators
    class BenchmarkGeneratorTest < Rails::Generators::TestCase
      include GeneratorsTestHelper

      setup do
        copy_gemfile
      end

      test "generate benchmark" do
        run_generator ["my_benchmark"]

        assert_file("Gemfile") do |content|
          assert_match "gem 'benchmark-ips'", content
        end

        assert_file("script/benchmarks/my_benchmark.rb") do |content|
          assert_equal <<~RUBY, content
            # frozen_string_literal: true

            require_relative "../../config/environment"

            # Any benchmarking setup goes here...



            Benchmark.ips do |x|
              x.report("before") { }
              x.report("after") { }

              x.compare!
            end
          RUBY
        end
      end

      test "generate benchmark with no name" do
        output = capture(:stderr) do
          run_generator []
        end

        assert_equal <<~MSG, output
          No value provided for required arguments 'name'
        MSG
      end

      test "generate benchmark with reports" do
        run_generator ["my_benchmark", "with_patch", "without_patch"]

        assert_file("script/benchmarks/my_benchmark.rb") do |content|
          assert_equal <<~RUBY, content
            # frozen_string_literal: true

            require_relative "../../config/environment"

            # Any benchmarking setup goes here...



            Benchmark.ips do |x|
              x.report("with_patch") { }
              x.report("without_patch") { }

              x.compare!
            end
          RUBY
        end
      end

      test "generate benchmark twice only adds ips gem once" do
        run_generator ["my_benchmark"]
        run_generator ["my_benchmark"]

        assert_file("Gemfile") do |content|
          occurrences = content.scan("gem 'benchmark-ips'").count
          assert_equal 1, occurrences, "Should only have benchmark-ips present once"
        end
      end
    end
  end
end
