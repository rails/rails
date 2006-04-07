class Tag < ActiveRecord::Base
  has_many :taggings
  has_many :taggables, :through => :taggings
  has_one  :tagging
end