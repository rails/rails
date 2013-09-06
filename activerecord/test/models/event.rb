class Event < ApplicationModel
  validates_uniqueness_of :title
end