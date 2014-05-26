class Rating < ActiveRecord::Base
  belongs_to :comment
  has_many :taggings, :as => :taggable
end

class SpecialRating < Rating
  belongs_to :special_comment
end
