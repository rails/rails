require 'generators/generators_test_helper'
require 'rails/generators/rails/generator/generator_generator'

class GeneratorGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper
  arguments %w(awesome)

  def test_generator_skeleton_is_created
    run_generator

    %w(
      lib/generators/awesome
      lib/generators/awesome/USAGE
      lib/generators/awesome/templates
    ).each{ |path| assert_file path }

    assert_file "lib/generators/awesome/awesome_generator.rb",
                /class AwesomeGenerator < Rails::Generators::NamedBase/
  end
end
