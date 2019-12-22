# frozen_string_literal: true

require "active_support/core_ext/object/try"

module ActionText
  module Attachments
    module TrixConversion
      extend ActiveSupport::Concern

      class_methods do
        def fragment_by_converting_trix_attachments(content)
          Fragment.wrap(content).replace(TrixAttachment::SELECTOR) do |node|
            from_trix_attachment(TrixAttachment.new(node))
          end
        end

        def from_trix_attachment(trix_attachment)
          from_attributes(trix_attachment.attributes)
        end
      end

      def to_trix_attachment(content = trix_attachment_content)
        attributes = full_attributes.dup
        attributes["content"] = content if content
        TrixAttachment.from_attributes(attributes)
      end

      private
        def trix_attachment_content
          if partial_path = attachable.try(:to_trix_content_attachment_partial_path)
            ActionText::Content.renderer.render(partial: partial_path, object: self, as: model_name.element)
          end
        end
    end
  end
end
