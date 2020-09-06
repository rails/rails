# frozen_string_literal: true

class Tag < ActiveRecord::Base
  has_many :taggings
  has_many :taggables, through: :taggings
  has_one  :tagging

  has_many :tagged_posts, through: :taggings, source: 'taggable', source_type: 'Post'
end

class OrderedTag < Tag
  self.table_name = 'tags'

  has_many :ordered_taggings, -> { order('taggings.id DESC') }, foreign_key: 'tag_id', class_name: 'Tagging'
  has_many :tagged_posts, through: :ordered_taggings, source: 'taggable', source_type: 'Post'
end
