# frozen_string_literal: true

# :markup: markdown

module Rails
  class TestUnitRailtie < Rails::Railtie
    config.app_generators do |c|
      c.test_framework :test_unit, fixture: true,
                                   fixture_replacement: nil

      c.integration_tool :test_unit
      c.system_tests :test_unit
    end

    initializer "test_unit.line_filtering" do
      ActiveSupport.on_load(:active_support_test_case) {
        # Required here so that the test runner, and the Rake and Prism it loads,
        # are only loaded when testing.
        require "rails/test_unit/line_filtering"
        ActiveSupport::TestCase.extend Rails::LineFiltering
      }
    end

    rake_tasks do
      load "rails/test_unit/testing.rake"
    end
  end
end
