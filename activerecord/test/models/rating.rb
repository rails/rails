class Rating < ActiveRecord::Base
  belongs_to :comment
  has_many :taggings, :as => :taggable
end
