class Owner < ActiveRecord::Base
  self.primary_key = :owner_id
  has_many :pets, -> { order 'pets.name desc' }
  has_many :toys, :through => :pets
end
