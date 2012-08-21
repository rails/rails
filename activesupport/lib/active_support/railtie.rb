require "active_support"
require "active_support/i18n_railtie"

module ActiveSupport
  class Railtie < Rails::Railtie
    config.active_support = ActiveSupport::OrderedOptions.new

    config.eager_load_namespaces << ActiveSupport

    initializer "active_support.deprecation_behavior" do |app|
      if deprecation = app.config.active_support.deprecation
        ActiveSupport::Deprecation.behavior = deprecation
      end
    end

    # Sets the default value for Time.zone
    # If assigned value cannot be matched to a TimeZone, an exception will be raised.
    initializer "active_support.initialize_time_zone" do |app|
      require 'active_support/core_ext/time/zones'
      zone_default = Time.find_zone!(app.config.time_zone)

      unless zone_default
        raise 'Value assigned to config.time_zone not recognized. ' \
          'Run "rake -D time" for a list of tasks for finding appropriate time zone names.'
      end

      Time.zone_default = zone_default
    end

    initializer "active_support.set_configs" do |app|
      app.config.active_support.each do |k, v|
        k = "#{k}="
        ActiveSupport.send(k, v) if ActiveSupport.respond_to? k
      end
    end
  end
end
