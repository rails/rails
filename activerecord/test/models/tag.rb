class Tag < ActiveRecord::Base
  has_many :taggings
  has_many :taggables, :through => :taggings
  has_one  :tagging

  has_many :tagged_posts, :through => :taggings, :source => "taggable", :source_type => "Post"
end

class OrderedTag < Tag
  self.table_name = "tags"

  has_many :taggings, -> { order("taggings.id DESC") }, foreign_key: "tag_id"
end
