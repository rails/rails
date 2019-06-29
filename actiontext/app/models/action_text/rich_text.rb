# frozen_string_literal: true

module ActionText
  # The RichText record holds the content produced by the Trix editor in a serialized +body+ attribute.
  # It also holds all the references to the embedded files, which are stored using Active Storage.
  # This record is then associated with the Active Record model the application desires to have
  # rich text content using the +has_rich_text+ class method.
  class RichText < ActiveRecord::Base
    self.table_name = "action_text_rich_texts"

    has_rich_text_field :body, attachment_field_name: :embeds
    delegate :to_s, :nil?, to: :body

    belongs_to :record, polymorphic: true, touch: true

    def to_plain_text
      body&.to_plain_text.to_s
    end

    delegate :blank?, :empty?, :present?, to: :to_plain_text
  end
end

ActiveSupport.run_load_hooks :action_text_rich_text, ActionText::RichText
