require 'generators/generator_test_helper'

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
end
