require "active_support"
require "rails"
require "active_support/i18n_railtie"

module ActiveSupport
  class Railtie < Rails::Railtie
    config.active_support = ActiveSupport::OrderedOptions.new

    # Loads support for "whiny nil" (noisy warnings when methods are invoked
    # on +nil+ values) if Configuration#whiny_nils is true.
    initializer "active_support.initialize_whiny_nils" do |app|
      require 'active_support/whiny_nil' if app.config.whiny_nils
    end

    # Sets the default value for Time.zone
    # If assigned value cannot be matched to a TimeZone, an exception will be raised.
    initializer "active_support.initialize_time_zone" do |app|
      require 'active_support/core_ext/time/zones'
      zone_default = Time.__send__(:get_zone, app.config.time_zone)

      unless zone_default
        raise \
          'Value assigned to config.time_zone not recognized.' +
          'Run "rake -D time" for a list of tasks for finding appropriate time zone names.'
      end

      Time.zone_default = zone_default
    end
  end
end