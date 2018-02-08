require "rails/engine"

module ActiveText
  class Engine < Rails::Engine
    isolate_namespace ActiveText
    config.eager_load_namespaces << ActiveText

    initializer "active_text.attribute" do
      ActiveSupport.on_load(:active_record) do
        include ActiveText::Attribute
      end
    end
  end
end
