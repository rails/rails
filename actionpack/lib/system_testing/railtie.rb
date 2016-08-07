module SystemTesting
  class Railtie < Rails::Railtie
    config.system_testing = ActiveSupport::OrderedOptions.new

    initializer "system_testing.set_configs" do |app|
      options = app.config.system_testing
      options.driver_adapter ||= :capybara_rack_test_driver

      ActiveSupport.on_load(:system_testing) do
        options.each { |k,v| send("#{k}=", v) }
      end
    end
  end
end
