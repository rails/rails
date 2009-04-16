class Pet < ActiveRecord::Base
  set_primary_key :pet_id
  belongs_to :owner, :touch => true
  has_many :toys
end
