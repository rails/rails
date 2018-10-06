class Message < ApplicationRecord
  has_rich_text :content
  has_rich_text :body
end
