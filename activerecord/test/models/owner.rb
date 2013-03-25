class Owner < ActiveRecord::Base
  self.primary_key = :owner_id
  has_many :pets
  has_many :toys, :through => :pets

  accepts_nested_attributes_for :pets, :allow_destroy => true
end
