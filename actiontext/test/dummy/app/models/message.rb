class Message < ApplicationRecord
  has_rich_text :content
  has_rich_text :body
  has_rich_text :rich_content, column: true

  has_one :review
  accepts_nested_attributes_for :review
end
