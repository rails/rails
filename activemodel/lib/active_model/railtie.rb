require "active_model"
require "rails"

module ActiveModel
  class Railtie < Rails::Railtie # :nodoc:
    config.eager_load_namespaces << ActiveModel

    initializer "active_model.secure_password" do
      ActiveModel::SecurePassword.min_cost = Rails.env.test?
    end

    initializer "activemodel.configure" do |app|
      ActiveModel::Translation.humanize_as_default = app.config.active_model.translation_humanize_as_default
    end
  end
end
