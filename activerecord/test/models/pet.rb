class Pet < ActiveRecord::Base
  set_primary_key :pet_id
  belongs_to :owner
  has_many :toys
end
