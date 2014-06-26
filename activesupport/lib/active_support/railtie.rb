require "active_support"
require "active_support/i18n_railtie"

module ActiveSupport
  class Railtie < Rails::Railtie
    config.active_support = ActiveSupport::OrderedOptions.new

    # Loads support for "whiny nil" (noisy warnings when methods are invoked
    # on +nil+ values) if Configuration#whiny_nils is true.
    initializer "active_support.initialize_whiny_nils" do |app|
      require 'active_support/whiny_nil' if app.config.whiny_nils
    end

    initializer "active_support.deprecation_behavior" do |app|
      if deprecation = app.config.active_support.deprecation
        ActiveSupport::Deprecation.behavior = deprecation
      else
        defaults = {"development" => :log,
                    "production"  => :notify,
                    "test"        => :stderr}

        env = Rails.env

        if defaults.key?(env)
          msg = "You did not specify how you would like Rails to report " \
                "deprecation notices for your #{env} environment, please " \
                "set config.active_support.deprecation to :#{defaults[env]} " \
                "at config/environments/#{env}.rb"

          warn msg
          ActiveSupport::Deprecation.behavior = defaults[env]
        else
          msg = "You did not specify how you would like Rails to report " \
                "deprecation notices for your #{env} environment, please " \
                "set config.active_support.deprecation to :log, :notify or " \
                ":stderr at config/environments/#{env}.rb"

          warn msg
          ActiveSupport::Deprecation.behavior = :stderr
        end
      end
    end

    # Sets the default value for Time.zone
    # If assigned value cannot be matched to a TimeZone, an exception will be raised.
    initializer "active_support.initialize_time_zone" do |app|
      require 'active_support/core_ext/time/zones'
      zone_default = Time.find_zone!(app.config.time_zone)

      unless zone_default
        raise \
          'Value assigned to config.time_zone not recognized.' +
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
