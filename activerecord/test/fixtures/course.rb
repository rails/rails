class Course < ActiveRecord::Base
  has_many :entrants
end
