# frozen_string_literal: true

require "generators/generators_test_helper"
require "rails/generators/rails/integration_test/integration_test_generator"

class IntegrationTestGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper

  def test_integration_test_skeleton_is_created
    run_generator %w(integration)
    assert_file "test/integration/integration_test.rb", /class IntegrationTest < ActionDispatch::IntegrationTest/
  end

  def test_namespaced_integration_test_skeleton_is_created
    run_generator %w(iguchi/integration)
    assert_file "test/integration/iguchi/integration_test.rb", /class Iguchi::IntegrationTest < ActionDispatch::IntegrationTest/
  end

  def test_test_suffix_is_not_duplicated
    run_generator %w(integration_test)

    assert_no_file "test/integration/integration_test_test.rb"
    assert_file "test/integration/integration_test.rb"
  end

  def test_rails_test_unit_railtie_is_undefined
    original_const = Rails.send(:remove_const, :TestUnitRailtie)

    assert_raises(RuntimeError) do
      run_generator %w(integration)
    end
    assert_no_file "test/integration/integration_test.rb"
  ensure
    Rails.const_set(:TestUnitRailtie, original_const)
  end
end
