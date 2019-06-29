class Post < ApplicationRecord
  has_many :comments
  accepts_nested_attributes_for :comments

  has_rich_text_field :custom_body
end
