class OwnedThing < ActiveRecord::Base
  belongs_to :owned_thing_owner
  def reset_owner
    new_owner = OwnedThingOwner.where.not(id: self.owned_thing_owner.id).first
    if new_owner.present?
      self.owned_thing_owner = new_owner
      save
    else
      raise ActiveRecord::RecordNotSaved
    end
  end
end
