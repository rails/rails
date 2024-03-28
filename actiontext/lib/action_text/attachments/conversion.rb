# frozen_string_literal: true

# :markup: markdown

require "active_support/core_ext/object/try"

module ActionText
  module Attachments
    module Conversion # :nodoc:
      extend ActiveSupport::Concern

      def to_editor_attachment(editor_name, content = editor_attachment_content(editor_name))
        attributes = full_attributes.dup
        attributes["content"] = content if content
        RichText.editors.fetch(editor_name).attachment_from_attributes(attributes)
      end

      private
        def editor_attachment_content(editor_name)
          if partial_path = attachable.try(:to_editor_content_attachment_partial_path, editor_name)
            ActionText::Content.render(partial: partial_path, formats: :html, object: self, as: model_name.element)
          end
        end
    end
  end
end
