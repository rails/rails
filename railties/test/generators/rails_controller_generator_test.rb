require 'generators/generator_test_helper'

module Admin
end

class RailsControllerGeneratorTest < GeneratorTestCase

  def test_controller_generates_controller
    run_generator('controller', %w(products))

    assert_generated_controller_for :products
    assert_generated_functional_test_for :products
    assert_generated_helper_for :products
  end

  def test_controller_generates_namespaced_controller
    run_generator('controller', %w(admin::products))

    assert_generated_controller_for "admin::products"
    assert_generated_functional_test_for "admin::products"
    assert_generated_helper_for "admin::products"
  end

  def test_controller_generates_namespaced_and_not_namespaced_controllers
      run_generator('controller', %w(products))

      # We have to require the generated helper to show the problem because
      # the test helpers just check for generated files and contents but
      # do not actually load them. But they have to be loaded (as in a real environment)
      # to make the second generator run fail
      require "#{RAILS_ROOT}/app/helpers/products_helper"

      assert_nothing_raised do
        begin
          run_generator('controller', %w(admin::products))
        ensure
          # cleanup
          Object.send(:remove_const, :ProductsHelper)
        end
      end
  end
end
