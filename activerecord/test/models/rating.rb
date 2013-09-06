class Rating < ApplicationModel
  belongs_to :comment
  has_many :taggings, :as => :taggable
end
