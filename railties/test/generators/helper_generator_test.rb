require 'abstract_unit'
require 'generators/generators_test_helper'
require 'generators/rails/helper/helper_generator'

ObjectHelper = Class.new
AnotherObjectHelperTest = Class.new

class HelperGeneratorTest < GeneratorsTestCase

  def test_helper_skeleton_is_created
    run_generator
    assert_file "app/helpers/admin_helper.rb", /module AdminHelper/
  end

  def test_invokes_default_test_framework
    run_generator
    assert_file "test/unit/helpers/admin_helper_test.rb", /class AdminHelperTest < ActionView::TestCase/
  end

  def test_logs_if_the_test_framework_cannot_be_found
    content = run_generator ["admin", "--test-framework=rspec"]
    assert_match /rspec \[not found\]/, content
  end

  def test_check_class_collision
    content = capture(:stderr){ run_generator ["object"] }
    assert_match /The name 'ObjectHelper' is either already used in your application or reserved/, content
  end

  def test_check_class_collision_on_tests
    content = capture(:stderr){ run_generator ["another_object"] }
    assert_match /The name 'AnotherObjectHelperTest' is either already used in your application or reserved/, content
  end

  def test_namespaced_and_not_namespaced_helpers
    run_generator ["products"]

    # We have to require the generated helper to show the problem because
    # the test helpers just check for generated files and contents but
    # do not actually load them. But they have to be loaded (as in a real environment)
    # to make the second generator run fail
    require "#{destination_root}/app/helpers/products_helper"

    assert_nothing_raised do
      begin
        run_generator ["admin::products"]
      ensure
        # cleanup
        Object.send(:remove_const, :ProductsHelper)
      end
    end
  end

  protected

    def run_generator(args=["admin"])
      silence(:stdout) { Rails::Generators::HelperGenerator.start args, :destination_root => destination_root }
    end

end
