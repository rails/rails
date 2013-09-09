class Movie < ApplicationRecord
  self.primary_key = "movieid"

  validates_presence_of :name
end
