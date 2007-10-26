class Pirate < ActiveRecord::Base
  belongs_to :parrot
  has_and_belongs_to_many :parrots
end
