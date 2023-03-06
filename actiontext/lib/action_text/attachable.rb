# frozen_string_literal: true

module ActionText
  module Attachable
    extend ActiveSupport::Concern

    LOCATOR_NAME = "attachable"

    class << self
      def from_node(node)
        if attachable = attachable_from_sgid(node["sgid"])
          attachable
        elsif attachable = ActionText::Attachables::ContentAttachment.from_node(node)
          attachable
        elsif attachable = ActionText::Attachables::RemoteImage.from_node(node)
          attachable
        else
          ActionText::Attachables::MissingAttachable
        end
      end

      def from_attachable_sgid(sgid, options = {})
        method = sgid.is_a?(Array) ? :locate_many_signed : :locate_signed
        record = GlobalID::Locator.public_send(method, sgid, options.merge(for: LOCATOR_NAME))
        record || raise(ActiveRecord::RecordNotFound)
      end

      private
        def attachable_from_sgid(sgid)
          from_attachable_sgid(sgid)
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
      super.merge("attachable_sgid" => persisted? ? attachable_sgid : nil)
    end

    def to_trix_content_attachment_partial_path
      to_partial_path
    end

    def to_attachable_partial_path
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
