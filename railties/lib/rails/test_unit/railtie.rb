module Rails
  class TestUnitRailtie < Rails::Railtie
    railtie_name :test_unit

    config.generators do |c|
      c.test_framework :test_unit, :fixture => true,
                                   :fixture_replacement => nil

      c.integration_tool :test_unit
      c.performance_tool :test_unit
    end

    rake_tasks do
      load "rails/test_unit/testing.rake"
    end

    initializer "test_unit.backtrace_cleaner" do
      # TODO: Figure out how to get the Rails::BacktraceFilter into minitest/unit
      unless defined?(Minitest) || ENV['BACKTRACE']
        require 'rails/backtrace_cleaner'
        Test::Unit::Util::BacktraceFilter.module_eval { include Rails::BacktraceFilterForTestUnit }
      end
    end
  end
end