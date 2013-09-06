class Movie < ApplicationModel
  self.primary_key = "movieid"

  validates_presence_of :name
end
