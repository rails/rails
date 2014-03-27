class Movie < ActiveRecord::Base
  def self.primary_key
    "movieid"
  end

  validates_presence_of :name
end
