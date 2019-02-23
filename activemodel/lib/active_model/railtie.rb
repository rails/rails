# frozen_string_literal: true

require "active_model"
require "rails"

module ActiveModel
  class Railtie < Rails::Railtie # :nodoc:
    config.eager_load_namespaces << ActiveModel

    config.active_model = ActiveSupport::OrderedOptions.new

    initializer "active_model.secure_password" do
      ActiveModel::SecurePassword.min_cost = Rails.env.test?
    end

    initializer "active_model.i18n_full_message" do
      ActiveModel::Errors.i18n_full_message = config.active_model.delete(:i18n_full_message) || false
    end

    initializer "active_model.enforce_i18n_naming" do
      ActiveModel::Naming.enforce_i18n_naming = config.active_model.delete(:enforce_i18n_naming) || false
    end
  end
end
