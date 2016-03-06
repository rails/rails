class Organizer < ActiveRecord::Base
  has_and_belongs_to_many :genres
  belongs_to :organization
end