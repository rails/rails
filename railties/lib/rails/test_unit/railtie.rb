module Rails
  class TestUnitRailtie < Rails::Railtie
    config.app_generators do |c|
      c.test_framework :test_unit, :fixture => true,
                                   :fixture_replacement => nil

      c.integration_tool :test_unit
      c.performance_tool :test_unit
    end

    rake_tasks do
      load "rails/test_unit/testing.rake"
    end
  end
end
