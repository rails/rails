class Movie < ActiveRecord::Base
  def self.primary_key
    "movieid"
  end
end
