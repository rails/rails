require "rails/engine"

module ActiveText
  class Engine < Rails::Engine
    isolate_namespace ActiveText
    config.eager_load_namespaces << ActiveText
  end
end
