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

    initializer "active_text.active_storage_extension" do
      require "active_storage/blob"

      class ActiveStorage::Blob
        include ActiveText::Attachable

        def previewable_attachable?
          representable?
        end
      end
    end

    initializer "active_text.helper" do
      ActiveSupport.on_load(:action_controller_base) do
        helper ActiveText::TagHelper
      end
    end

    initializer "active_text.config" do
      config.after_initialize do |app|
        ActiveText.renderer ||= ApplicationController.renderer

        # FIXME: ApplicationController should have a per-request specific renderer 
        # that's been set with the request.env env, and ActiveText should just piggyback off
        # that by default rather than doing this work directly.
        ApplicationController.before_action do
          ActiveText.renderer = ActiveText.renderer.new(request.env)
        end
      end
    end
  end
end
