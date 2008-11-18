require File.dirname(__FILE__) + '/generator_test_helper'

class RailsHelperGeneratorTest < GeneratorTestCase
  def test_helper_generates_helper
    run_generator('helper', %w(products))

    assert_generated_helper_for :products
    assert_generated_helper_test_for :products
  end

  def test_helper_generates_namespaced_helper
    run_generator('helper', %w(admin::products))

    assert_generated_helper_for "admin::products"
    assert_generated_helper_test_for "admin::products"
  end

  def test_helper_generates_namespaced_and_not_namespaced_helpers
    run_generator('helper', %w(products))

    # We have to require the generated helper to show the problem because
    # the test helpers just check for generated files and contents but
    # do not actually load them. But they have to be loaded (as in a real environment)
    # to make the second generator run fail
    require "#{RAILS_ROOT}/app/helpers/products_helper"

    assert_nothing_raised do
      begin
        run_generator('helper', %w(admin::products))
      ensure
        # cleanup
        Object.send(:remove_const, :ProductsHelper)
      end
    end
  end
end
