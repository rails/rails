class Membership < ActiveRecord::Base
  belongs_to :member
  belongs_to :club
end

class CurrentMembership < Membership
  belongs_to :member
  belongs_to :club
end

class SuperMembership < Membership
  belongs_to :member, -> { order('members.id DESC') }
  belongs_to :club
end

class SelectedMembership < Membership
  def self.default_scope
    select("'1' as foo")
  end
end
