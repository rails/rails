class Message < ApplicationRecord
  include ActionText::Attachable

  has_rich_text :content
  has_rich_text :body

  has_one :review
  accepts_nested_attributes_for :review
end
