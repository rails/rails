class Owner < ActiveRecord::Base
  set_primary_key :owner_id
  has_many :pets
  has_many :toys, :through => :pets
end
