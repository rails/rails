# frozen_string_literal: true

require "rails"
require "active_model"

module ActiveModel
  class Railtie < Rails::Railtie # :nodoc:
    config.eager_load_namespaces << ActiveModel

    config.active_model = ActiveSupport::OrderedOptions.new

    initializer "active_model.deprecator", before: :load_environment_config do |app|
      app.deprecators[:active_model] = ActiveModel.deprecator
    end

    initializer "active_model.secure_password" do
      ActiveSupport.on_load(:active_model_secure_password) do
        ActiveModel::SecurePassword.min_cost = Rails.env.test?
      end
    end

    initializer "active_model.i18n_customize_full_message" do |app|
      ActiveSupport.on_load(:active_model_error) do
        ActiveModel::Error.i18n_customize_full_message = app.config.active_model.i18n_customize_full_message || false
      end
    end
  end
end
