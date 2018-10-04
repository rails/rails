# The RichText record holds the content produced by the Trix editor in a serialized `body` attribute.
# It also holds all the references to the embedded files, which are stored using Active Storage.
# This record is then associated with the Active Record model the application desires to have
# rich text content using the `has_rich_text` class method.
class ActionText::RichText < ActiveRecord::Base
  self.table_name = "action_text_rich_texts"

  serialize :body, ActionText::Content
  delegate :to_s, :to_plain_text, :nil?, to: :body
  delegate :blank?, :empty?, :present?, to: :to_s

  belongs_to :record, polymorphic: true, touch: true
  has_many_attached :embeds

  before_save do
    self.embeds = body.attachments.map(&:attachable) if body.present?
  end
end
