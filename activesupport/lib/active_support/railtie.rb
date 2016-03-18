require "active_support"
require "active_support/i18n_railtie"

module ActiveSupport
  class Railtie < Rails::Railtie # :nodoc:
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
      begin
        TZInfo::DataSource.get
      rescue TZInfo::DataSourceNotFound => e
        raise e.exception "tzinfo-data is not present. Please add gem 'tzinfo-data' to your Gemfile and run bundle install"
      end
      require 'active_support/core_ext/time/zones'
      zone_default = Time.find_zone!(app.config.time_zone)

      unless zone_default
        raise 'Value assigned to config.time_zone not recognized. ' \
          'Run "rake time:zones:all" for a time zone names list.'
      end

      Time.zone_default = zone_default
    end

    # Sets the default week start
    # If assigned value is not a valid day symbol (e.g. :sunday, :monday, ...), an exception will be raised.
    initializer "active_support.initialize_beginning_of_week" do |app|
      require 'active_support/core_ext/date/calculations'
      beginning_of_week_default = Date.find_beginning_of_week!(app.config.beginning_of_week)

      Date.beginning_of_week_default = beginning_of_week_default
    end

    initializer "active_support.set_configs" do |app|
      app.config.active_support.each do |k, v|
        k = "#{k}="
        ActiveSupport.send(k, v) if ActiveSupport.respond_to? k
      end
    end
  end
end
