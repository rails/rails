require "rails/engine"

module ActiveText
  class Engine < Rails::Engine
    config.eager_load_namespaces << ActiveText
  end
end
