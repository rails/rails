# frozen_string_literal: true

module ActionText
  module Attachable
    extend ActiveSupport::Concern

    LOCATOR_NAME = "attachable"

    class << self
      def from_node(node, attachment_blobs)
        if attachable = attachable_from_sgid(node["sgid"], attachment_blobs)
          attachable
        elsif attachable = ActionText::Attachables::ContentAttachment.from_node(node)
          attachable
        elsif attachable = ActionText::Attachables::RemoteImage.from_node(node)
          attachable
        else
          ActionText::Attachables::MissingAttachable
        end
      end

      def from_attachable_sgid(sgid, attachment_blobs, options = {})
        options = options.merge(for: LOCATOR_NAME)

        record =
          if attachment_blobs.present?
            if sgid.is_a?(Array)
              sgids.collect do |id|
                id = SignedGlobalID.parse(id, options).model_id
                attachment_blobs[id]
              end.compact
            else
              id = SignedGlobalID.parse(sgid, options).model_id
              attachment_blobs[id]
            end
          else
            method = sgid.is_a?(Array) ? :locate_many_signed : :locate_signed
            GlobalID::Locator.public_send(method, sgid, options)
          end

        record || raise(ActiveRecord::RecordNotFound)
      end

      private
        def attachable_from_sgid(sgid, attachment_blobs)
          from_attachable_sgid(sgid, attachment_blobs)
        rescue ActiveRecord::RecordNotFound
          nil
        end
    end

    class_methods do
      def from_attachable_sgid(sgid)
        ActionText::Attachable.from_attachable_sgid(sgid, only: self)
      end
    end

    def attachable_sgid
      to_sgid(expires_in: nil, for: LOCATOR_NAME).to_s
    end

    def attachable_content_type
      try(:content_type) || "application/octet-stream"
    end

    def attachable_filename
      filename.to_s if respond_to?(:filename)
    end

    def attachable_filesize
      try(:byte_size) || try(:filesize)
    end

    def attachable_metadata
      try(:metadata) || {}
    end

    def previewable_attachable?
      false
    end

    def as_json(*)
      super.merge(attachable_sgid: attachable_sgid)
    end

    def to_trix_content_attachment_partial_path
      to_partial_path
    end

    def to_rich_text_attributes(attributes = {})
      attributes.dup.tap do |attrs|
        attrs[:sgid] = attachable_sgid
        attrs[:content_type] = attachable_content_type
        attrs[:previewable] = true if previewable_attachable?
        attrs[:filename] = attachable_filename
        attrs[:filesize] = attachable_filesize
        attrs[:width] = attachable_metadata[:width]
        attrs[:height] = attachable_metadata[:height]
      end.compact
    end
  end
end
