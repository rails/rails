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

    # FIXME: Aren't helpers supposed to load automatically?
    # https://github.com/rails/rails/issues/26627 ?
    initializer "active_text.helper" do
      ActiveSupport.on_load(:action_controller_base) do
        helper ActiveText::TagHelper
      end
    end
  end
end
