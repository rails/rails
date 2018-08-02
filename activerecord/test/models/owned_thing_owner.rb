class OwnedThingOwner < ActiveRecord::Base
  has_many :owned_things, dependent: :reset_owner
end
