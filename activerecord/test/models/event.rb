class Event < ApplicationRecord
  validates_uniqueness_of :title
end