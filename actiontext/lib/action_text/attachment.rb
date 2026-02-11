# frozen_string_literal: true

# :markup: markdown

require "active_support/core_ext/object/try"
require "active_support/inspect_backport"

module ActionText
  # # Action Text Attachment
  #
  # Attachments serialize attachables to HTML or plain text.
  #
  #     class Person < ApplicationRecord
  #       include ActionText::Attachable
  #     end
  #
  #     attachable = Person.create! name: "Javan"
  #     attachment = ActionText::Attachment.from_attachable(attachable)
  #     attachment.to_html # => "<action-text-attachment sgid=\"BAh7CEk..."
  class Attachment
    include Attachments::TrixConversion, Attachments::Minification, Attachments::Caching, Attachments::Conversion

    mattr_accessor :tag_name, default: "action-text-attachment"

    ATTRIBUTES = %w( sgid content-type url href filename filesize width height previewable presentation caption content )

    class << self
      def fragment_by_canonicalizing_attachments(content)
        fragment_by_minifying_attachments(fragment_by_converting_editor_attachments(content))
      end

      def from_node(node, attachable = nil)
        new(node, attachable || ActionText::Attachable.from_node(node))
      end

      def from_attachables(attachables)
        Array(attachables).filter_map { |attachable| from_attachable(attachable) }
      end

      def from_attachable(attachable, attributes = {})
        if node = node_from_attributes(attachable.to_rich_text_attributes(attributes))
          new(node, attachable)
        end
      end

      def from_attributes(attributes, attachable = nil)
        if node = node_from_attributes(attributes)
          from_node(node, attachable)
        end
      end

      private
        def node_from_attributes(attributes)
          if attributes = process_attributes(attributes).presence
            ActionText::HtmlConversion.create_element(tag_name, attributes)
          end
        end

        def process_attributes(attributes)
          attributes.transform_keys { |key| key.to_s.underscore.dasherize }.slice(*ATTRIBUTES)
        end
    end

    attr_reader :node, :attachable

    delegate :to_param, to: :attachable
    delegate_missing_to :attachable

    def initialize(node, attachable)
      @node = node
      @attachable = attachable
    end

    def caption
      node_attributes["caption"].presence
    end

    def full_attributes
      node_attributes.merge(attachable_attributes).merge(sgid_attributes)
    end

    def with_full_attributes
      self.class.from_attributes(full_attributes, attachable)
    end

    # Converts the attachment to plain text.
    #
    #     attachable = ActiveStorage::Blob.find_by filename: "racecar.jpg"
    #     attachment = ActionText::Attachment.from_attachable(attachable)
    #     attachment.to_plain_text # => "[racecar.jpg]"
    #
    # Use the `caption` when set:
    #
    #     attachment = ActionText::Attachment.from_attachable(attachable, caption: "Vroom vroom")
    #     attachment.to_plain_text # => "[Vroom vroom]"
    #
    # The presentation can be overridden by implementing the
    # `attachable_plain_text_representation` method:
    #
    #     class Person < ApplicationRecord
    #       include ActionText::Attachable
    #
    #       def attachable_plain_text_representation
    #         "[#{name}]"
    #       end
    #     end
    #
    #     attachable = Person.create! name: "Javan"
    #     attachment = ActionText::Attachment.from_attachable(attachable)
    #     attachment.to_plain_text # => "[Javan]"
    def to_plain_text
      if respond_to?(:attachable_plain_text_representation)
        attachable_plain_text_representation(caption)
      else
        caption.to_s
      end
    end

    # Converts the attachment to HTML.
    #
    #     attachable = Person.create! name: "Javan"
    #     attachment = ActionText::Attachment.from_attachable(attachable)
    #     attachment.to_html # => "<action-text-attachment sgid=\"BAh7CEk...
    def to_html
      HtmlConversion.node_to_html(node)
    end

    def to_s
      to_html
    end

    include ActiveSupport::InspectBackport if RUBY_VERSION < "4"

    private
      def instance_variables_to_inspect
        [:@attachable].freeze
      end

      def node_attributes
        @node_attributes ||= ATTRIBUTES.to_h { |name| [ name.underscore, node[name] ] }.compact
      end

      def attachable_attributes
        @attachable_attributes ||= (attachable.try(:to_rich_text_attributes) || {}).stringify_keys
      end

      def sgid_attributes
        @sgid_attributes ||= node_attributes.slice("sgid").presence || attachable_attributes.slice("sgid")
      end
  end
end
