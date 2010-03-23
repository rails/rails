require 'generators/generators_test_helper'
require 'rails/generators/rails/metal/metal_generator'

class MetalGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper
  arguments %w(foo)

  def test_metal_skeleton_is_created
    run_generator
    assert_file "app/metal/foo.rb", /class Foo/
  end

  def test_check_class_collision
    content = capture(:stderr){ run_generator ["object"] }
    assert_match /The name 'Object' is either already used in your application or reserved/, content
  end
end
