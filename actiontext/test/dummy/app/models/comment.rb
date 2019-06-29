class Comment < ApplicationRecord
  belongs_to :post

  has_rich_text_field :comment_contents
end
