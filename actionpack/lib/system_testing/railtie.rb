require 'system_test_case'

module SystemTesting
  # = System Testing Railtie
  class Railtie < Rails::Railtie # :nodoc:
    config.system_testing = ActiveSupport::OrderedOptions.new

    initializer "system_testing.set_configs" do |app|
      options = app.config.system_testing
      options.driver ||= Rails::SystemTestCase.default_driver

      ActiveSupport.on_load(:system_testing) do
        options.each { |k,v| send("#{k}=", v) }
      end
    end
  end
end
