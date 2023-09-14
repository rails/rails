# frozen_string_literal: true

module ActionText
  # = Action Text \Attachable
  #
  # Include this module to make a record attachable to an ActionText::Content.
  #
  #   class Person < ApplicationRecord
  #     include ActionText::Attachable
  #   end
  #
  #   person = Person.create! name: "Javan"
  #   html = %Q(<action-text-attachment sgid="#{person.attachable_sgid}"></action-text-attachment>)
  #   content = ActionText::Content.new(html)
  #   content.attachables # => [person]
  module Attachable
    extend ActiveSupport::Concern

    LOCATOR_NAME = "attachable"

    class << self
      # Extracts the +ActionText::Attachable+ from the attachment HTML node:
      #
      #   person = Person.create! name: "Javan"
      #   html = %Q(<action-text-attachment sgid="#{person.attachable_sgid}"></action-text-attachment>)
      #   fragment = ActionText::Fragment.wrap(html)
      #   attachment_node = fragment.find_all(ActionText::Attachment.tag_name).first
      #   ActionText::Attachable.from_node(attachment_node) # => person
      def from_node(node)
        if attachable = attachable_from_sgid(node["sgid"])
          attachable
        elsif attachable = ActionText::Attachables::ContentAttachment.from_node(node)
          attachable
        elsif attachable = ActionText::Attachables::RemoteImage.from_node(node)
          attachable
        else
          ActionText::Attachables::MissingAttachable.new(node["sgid"])
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

      # Returns the path to the partial that is used for rendering missing attachables.
      # Defaults to "action_text/attachables/missing_attachable".
      #
      # Override to render a different partial:
      #
      #   class User < ApplicationRecord
      #     def self.to_missing_attachable_partial_path
      #       "users/missing_attachable"
      #     end
      #   end
      def to_missing_attachable_partial_path
        ActionText::Attachables::MissingAttachable::DEFAULT_PARTIAL_PATH
      end
    end

    # Returns the Signed Global ID for the attachable. The purpose of the ID is
    # set to 'attachable' so it can't be reused for other purposes.
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

    # Returns the path to the partial that is used for rendering the attachable
    # in Trix. Defaults to +to_partial_path+.
    #
    # Override to render a different partial:
    #
    #   class User < ApplicationRecord
    #     def to_trix_content_attachment_partial_path
    #       "users/trix_content_attachment"
    #     end
    #   end
    def to_trix_content_attachment_partial_path
      to_partial_path
    end

    # Returns the path to the partial that is used for rendering the attachable.
    # Defaults to +to_partial_path+.
    #
    # Override to render a different partial:
    #
    #   class User < ApplicationRecord
    #     def to_attachable_partial_path
    #       "users/attachable"
    #     end
    #   end
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

    private
      def attribute_names_for_serialization
        super + ["attachable_sgid"]
      end

      def read_attribute_for_serialization(key)
        if key == "attachable_sgid"
          persisted? ? super : nil
        else
          super
        end
      end
  end
end
