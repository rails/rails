class Tag < ApplicationModel
  has_many :taggings
  has_many :taggables, :through => :taggings
  has_one  :tagging

  has_many :tagged_posts, :through => :taggings, :source => :taggable, :source_type => 'Post'
end