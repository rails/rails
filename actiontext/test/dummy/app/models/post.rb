class Post < ApplicationRecord
	belongs_to :message
	has_rich_text :content
end
