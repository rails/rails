# frozen_string_literal: true

# :markup: markdown

require "rails"
require "action_controller/railtie"
require "active_record/railtie"
require "active_storage/engine"

require "action_text"
require "action_text/trix"

module ActionText
  class Engine < Rails::Engine
    isolate_namespace ActionText
    config.eager_load_namespaces << ActionText

    config.action_text = ActiveSupport::OrderedOptions.new
    config.action_text.editors = ActiveSupport::InheritableOptions.new(
      trix: {}
    )
    config.action_text.editor = :trix
    config.action_text.attachment_tag_name = "action-text-attachment"
    config.autoload_once_paths = %W(
      #{root}/app/helpers
      #{root}/app/models
    )

    guard_load_hooks(
      :action_text_record, :action_text_rich_text, :action_text_content,
      :action_text_encrypted_rich_text,
    )

    initializer "action_text.deprecator", before: :load_environment_config do |app|
      app.deprecators[:action_text] = ActionText.deprecator
    end

    initializer "action_text.attribute" do
      ActiveSupport.on_load(:active_record) do
        include ActionText::Attribute
        prepend ActionText::Encryption
      end
    end

    initializer "action_text.asset" do
      if Rails.application.config.respond_to?(:assets)
        Rails.application.config.assets.precompile += %w( actiontext.js actiontext.esm.js )
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

        def attachable_markdown_representation(caption = nil)
          "[#{MarkdownConversion.escape_markdown_text((caption || filename).to_s)}]"
        end

        def to_trix_content_attachment_partial_path
          to_editor_content_attachment_partial_path
        end
        deprecate :to_trix_content_attachment_partial_path, deprecator: ActionText.deprecator

        def to_editor_content_attachment_partial_path
          nil
        end
      end
    end

    initializer "action_text.helper" do
      %i[action_controller_base action_mailer].each do |base|
        ActiveSupport.on_load(base) do
          helper ActionText::Engine.helpers
        end
      end
    end

    initializer "action_text.editors" do |app|
      ActiveSupport.on_load :action_text_rich_text do
        self.editors = Editor::Registry.new(app.config.action_text.editors)

        if (editor_name = app.config.action_text.editor)
          self.editor = editors.fetch(editor_name)
        end
      end
    end

    initializer "action_text.renderer" do
      %i[action_controller_base action_mailer].each do |base|
        ActiveSupport.on_load(base) do
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

    config.after_initialize do |app|
      if klass = app.config.action_text.sanitizer_vendor
        ActiveSupport.on_load(:action_view) do
          ActionText::ContentHelper.sanitizer = klass.safe_list_sanitizer.new
        end
      end
    end
  end
end
