# frozen_string_literal: true

# :markup: markdown

require "active_support/core_ext/object/try"

module ActionText
  module Attachments
    module Conversion # :nodoc:
      extend ActiveSupport::Concern

      class_methods do
        def fragment_by_converting_editor_attachments(content)
          RichText.editor.to_action_text_html(content)
        end
      end

      def to_editor_html(...)
        dup.to_editor_html!(...)
      end

      def to_editor_html!(content = editor_attachment_content) # :nodoc:
        node["content"] = content if content
        RichText.editor.to_editor_html(to_html)
      end

      private
        def editor_attachment_content
          if partial_path = (
              attachable.try(:to_editor_content_attachment_partial_path) ||
              ActionText.deprecator.silence { attachable.try(:to_trix_content_attachment_partial_path) }
            )
            ActionText::Content.render(partial: partial_path, formats: :html, object: self, as: model_name.element)
          end
        end
    end
  end
end
