# frozen_string_literal: true

require "rails"
require "action_controller/railtie"
require "active_record/railtie"
require "active_storage/engine"

require "action_text"

module ActionText
  class Engine < Rails::Engine
    isolate_namespace ActionText
    config.eager_load_namespaces << ActionText

    config.action_text = ActiveSupport::OrderedOptions.new
    config.action_text.attachment_tag_name = "action-text-attachment"
    config.autoload_once_paths = %W(
      #{root}/app/helpers
      #{root}/app/models
    )

    initializer "action_text.attribute" do
      ActiveSupport.on_load(:active_record) do
        include ActionText::Attribute
        prepend ActionText::Encryption
      end
    end

    initializer "action_text.attachable" do
      ActiveSupport.on_load(:active_storage_blob) do
        include ActionText::Attachable

        def previewable_attachable?
          representable?
        end

        def attachable_plain_text_representation(caption = nil)
          "[#{caption || filename}]"
        end

        def to_trix_content_attachment_partial_path
          nil
        end
      end
    end

    initializer "action_text.helper" do
      %i[action_controller_base action_mailer].each do |abstract_controller|
        ActiveSupport.on_load(abstract_controller) do
          helper ActionText::Engine.helpers
        end
      end
    end

    initializer "action_text.renderer" do
      ActiveSupport.on_load(:action_text_content) do
        self.default_renderer = Class.new(ActionController::Base).renderer
      end

      %i[action_controller_base action_mailer].each do |abstract_controller|
        ActiveSupport.on_load(abstract_controller) do
          around_action do |controller, action|
            ActionText::Content.with_renderer(controller, &action)
          end
        end
      end
    end

    initializer "action_text.system_test_helper" do
      ActiveSupport.on_load(:action_dispatch_system_test_case) do
        require "action_text/system_test_helper"
        include ActionText::SystemTestHelper
      end
    end

    initializer "action_text.configure" do |app|
      ActionText::Attachment.tag_name = app.config.action_text.attachment_tag_name
    end
  end
end
