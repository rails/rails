require 'abstract_unit'
require 'generators/generators_test_helper'
require 'generators/rails/performance_test/performance_test_generator'

class PerformanceTestGeneratorTest < GeneratorsTestCase

  def test_performance_test_skeleton_is_created
    run_generator
    assert_file "test/performance/performance_test.rb", /class PerformanceTest < ActionController::PerformanceTest/
  end

  protected

    def run_generator(args=["performance"])
      silence(:stdout) { Rails::Generators::PerformanceTestGenerator.start args, :destination_root => destination_root }
    end

end
