class Message < ApplicationRecord
  has_rich_text :content
  has_rich_text :body

  rich_text_column :rich_content

  has_one :review
  accepts_nested_attributes_for :review
end
