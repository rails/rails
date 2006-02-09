class Tag < ActiveRecord::Base
  has_many :taggings, :as => :taggable
  has_one  :tagging,  :as => :taggable
end