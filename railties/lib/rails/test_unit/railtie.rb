require "rails/test_unit/line_filtering"

if defined?(Rake.application) && Rake.application.top_level_tasks.grep(/^(default$|test(:|$))/).any?
  ENV["RAILS_ENV"] ||= "test"
end

module Rails
  class TestUnitRailtie < Rails::Railtie
    config.app_generators do |c|
      c.test_framework :test_unit, fixture: true,
                                   fixture_replacement: nil

      c.integration_tool :test_unit
      c.system_tool :test_unit
    end

    initializer "test_unit.line_filtering" do
      ActiveSupport.on_load(:active_support_test_case) {
        ActiveSupport::TestCase.extend Rails::LineFiltering
      }
    end

    config.system_testing = ActiveSupport::OrderedOptions.new

    initializer "system_testing.set_configs" do |app|
      ActiveSupport.on_load(:active_support_test_case) do
        require "action_system_test"

        options = app.config.system_testing
        options.driver ||= ActionSystemTest.default_driver
        options.each { |k, v| ActionSystemTest.send("#{k}=", v) }
      end
    end

    rake_tasks do
      load "rails/test_unit/testing.rake"
    end
  end
end
