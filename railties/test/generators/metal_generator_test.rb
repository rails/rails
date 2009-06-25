require 'abstract_unit'
require 'generators/generators_test_helper'
require 'generators/rails/metal/metal_generator'

class MetalGeneratorTest < GeneratorsTestCase

  def test_metal_skeleton_is_created
    run_generator
    assert_file "app/metal/foo.rb", /class Foo/
  end

  protected

    def run_generator(args=[])
      silence(:stdout) { Rails::Generators::MetalGenerator.start ["foo"].concat(args), :root => destination_root }
    end

end
