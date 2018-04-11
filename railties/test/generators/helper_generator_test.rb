# frozen_string_literal: true

require "generators/generators_test_helper"
require "rails/generators/rails/helper/helper_generator"

ObjectHelper = Class.new
AnotherObjectHelperTest = Class.new

class HelperGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper
  arguments %w(admin)

  def test_helper_skeleton_is_created
    run_generator
    assert_file "app/helpers/admin_helper.rb", /module AdminHelper/
  end

  def test_check_class_collision
    content = capture(:stderr) { run_generator ["object"] }
    assert_match(/The name 'ObjectHelper' is either already used in your application or reserved/, content)
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

  def test_file_is_opened_in_editor
    generator ["products"], editor: "cat"

    assert_called_with(generator, :run, ["cat app/helpers/products_helper.rb"]) do
      quietly { generator.invoke_all }
    end
  end
end
