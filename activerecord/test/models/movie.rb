class Movie < ApplicationRecord
  def self.primary_key
    "movieid"
  end
end
