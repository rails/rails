# frozen_string_literal: true

module ActionText
  # The RichText record holds the content produced by the Trix editor in a serialized +body+ attribute.
  # It also holds all the references to the embedded files, which are stored using Active Storage.
  # This record is then associated with the Active Record model the application desires to have
  # rich text content using the +has_rich_text+ class method.
  class RichText < Record
    self.table_name = "action_text_rich_texts"

    serialize :body, ActionText::Content
    delegate :to_s, :nil?, to: :body

    belongs_to :record, polymorphic: true, touch: true
    has_many_attached :embeds

    before_save do
      self.embeds = body.attachables.grep(ActiveStorage::Blob).uniq if body.present?
    end

    def to_plain_text
      body&.to_plain_text.to_s
    end

    delegate :blank?, :empty?, :present?, to: :to_plain_text
  end
end

ActiveSupport.run_load_hooks :action_text_rich_text, ActionText::RichText
