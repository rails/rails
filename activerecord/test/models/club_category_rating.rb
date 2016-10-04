class ClubCategoryRating < ActiveRecord::Base
  belongs_to :club
  belongs_to :category
end
