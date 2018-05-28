class ActionText::RichText < ActiveRecord::Base
  self.table_name = "action_text_rich_texts"

  serialize :body, ActionText::Content
  
  has_many_attached :embeds

  after_save do
    self.embeds_attachments_blobs = body.attachments.map(&:attachable)
  end
end
