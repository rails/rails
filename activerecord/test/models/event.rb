class Event < ActiveRecord::Base
  validates :title, uniqueness: true
end