require 'generators/generator_test_helper'

class RailsResourceGeneratorTest < GeneratorTestCase
  def test_resource_generates_resources
    run_generator('resource', %w(Product name:string))

    assert_generated_controller_for :products
    assert_generated_model_for :product
    assert_generated_fixtures_for :products
    assert_generated_functional_test_for :products
    assert_generated_helper_for :products
    assert_generated_helper_test_for :products
    assert_generated_migration :create_products
    assert_added_route_for :products
  end

  def test_resource_skip_migration_skips_migration
    run_generator('resource', %w(Product name:string --skip-migration))

    assert_generated_controller_for :products
    assert_generated_model_for :product
    assert_generated_fixtures_for :products
    assert_generated_functional_test_for :products
    assert_generated_helper_for :products
    assert_generated_helper_test_for :products
    assert_skipped_migration :create_products
    assert_added_route_for :products
  end
end
