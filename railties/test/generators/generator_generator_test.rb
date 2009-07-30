require 'abstract_unit'
require 'generators/generators_test_helper'
require 'generators/rails/generator/generator_generator'

class GeneratorGeneratorTest < GeneratorsTestCase

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

  protected

    def run_generator(args=["awesome"], config={})
      silence(:stdout) { Rails::Generators::GeneratorGenerator.start args, config.merge(:destination_root => destination_root) }
    end

end
