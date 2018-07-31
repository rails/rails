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
  end
end
