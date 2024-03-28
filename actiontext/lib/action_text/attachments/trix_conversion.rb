# frozen_string_literal: true

# :markup: markdown

require "active_support/core_ext/object/try"

module ActionText
  module Attachments
    # DEPRECATED
    module TrixConversion
      extend ActiveSupport::Concern

      class_methods do
        def fragment_by_converting_trix_attachments(content)
          RichText.editors.fetch(:trix).fragment_by_converting_attachments(content)
        end
        deprecate :fragment_by_converting_trix_attachments, deprecator: ActionText.deprecator

        def from_trix_attachment(trix_attachment)
          from_attributes(trix_attachment.attributes)
        end
        deprecate :from_trix_attachment, deprecator: ActionText.deprecator
      end

      def to_trix_attachment(content = editor_attachment_content(:trix))
        attributes = full_attributes.dup
        attributes["content"] = content if content
        TrixAttachment.from_attributes(attributes)
      end
      deprecate to_trix_attachment: :to_editor_attachment, deprecator: ActionText.deprecator

      private
        def trix_attachment_content
          if (partial_path = ActionText.deprecator.silence { attachable.try(:to_trix_content_attachment_partial_path) })
            ActionText::Content.render(partial: partial_path, formats: :html, object: self, as: model_name.element)
          end
        end
    end
  end
end
