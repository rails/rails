require 'generators/generators_test_helper'
require 'rails/generators/rails/module/module_generator'

class ModuleGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper
  arguments %w(custom method1 method2 method2)

  def test_controller_skeleton_is_created
    run_generator
    assert_file "lib/custom.rb", /module Custom/
  end
  
  def test_invokes_default_test_framework
    run_generator
    assert_file "test/unit/custom_test.rb", /class CustomTest < ActiveSupport::TestCase/
  end
end
