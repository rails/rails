require "active_model"
require "rails"

module ActiveModel
  class Railtie < Rails::Railtie
    config.eager_load_namespaces << ActiveModel
  end
end