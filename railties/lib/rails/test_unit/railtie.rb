module Rails
  class TestUnitRailtie < Rails::Railtie
    railtie_name :test_unit

    config.generators.test_framework :test_unit

    rake_tasks do
       load "rails/tasks/testing.rake"
     end
  end
end