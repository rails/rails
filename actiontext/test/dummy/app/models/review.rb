class Review < ApplicationRecord
  belongs_to :message

  has_rich_text :content
  has_rich_text :rich_content, column: true
end
