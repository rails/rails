class Tag < ActiveRecord::Base
  has_many :taggings, :as => :taggable
end