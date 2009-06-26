require 'abstract_unit'
require 'generators/generators_test_helper'
require 'generators/rails/integration_test/integration_test_generator'

class IntegrationTestGeneratorTest < GeneratorsTestCase

  def test_integration_test_skeleton_is_created
    run_generator
    assert_file "test/integration/integration_test.rb"
  end

  protected

    def run_generator(args=["integration"])
      silence(:stdout) { Rails::Generators::IntegrationTestGenerator.start args, :root => destination_root }
    end

end
