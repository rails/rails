class Universe < ActiveRecord::Base
  has_many :galaxies
  has_many :stars, :through => :galaxies
end
