class Tag < ActiveRecord::Base
  has_many :taggings,  :as => :taggable
  has_many :taggables, :through => :taggings
  has_one  :tagging,   :as => :taggable
end