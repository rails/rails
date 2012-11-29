require "active_model"
require "rails"

module ActiveModel
  class Railtie < Rails::Railtie # :nodoc:
    config.eager_load_namespaces << ActiveModel

    # Sets +ActiveModel::SecurePassword#cost+ to the minimum value allowed
    # by the bcrypt-ruby gem when running tests.
    initializer "active_model.secure_password" do
      if Rails.env.test?
        ActiveModel::SecurePassword.cost = 1
      end
    end
  end
end
