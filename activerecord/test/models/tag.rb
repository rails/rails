class Tag < ActiveRecord::Base
  has_many :taggings
  has_many :taggables, :through => :taggings
  has_one  :tagging

  has_many :tagged_posts, :through => :taggings, :source => :taggable, :source_type => 'Post'
  has_many :tagged_posts_with_destroy, :through => :taggings, :source => :taggable, :source_type => 'Post', :dependent => :destroy
end
