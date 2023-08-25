class Review < ApplicationRecord
  belongs_to :message

  has_rich_text :content
  rich_text_column :rich_content
end
