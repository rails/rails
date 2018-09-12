class ActionText::RichText < ActiveRecord::Base
  self.table_name = "action_text_rich_texts"

  serialize :body, ActionText::Content

  belongs_to :record, polymorphic: true, touch: true
  has_many_attached :embeds

  validate { errors.add(:body, "is missing") if body.blank? }

  before_save do
    self.embeds = body.attachments.map(&:attachable)
  end

  def to_s
    body.to_s.html_safe
  end
end
