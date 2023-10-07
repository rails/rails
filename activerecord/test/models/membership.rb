# frozen_string_literal: true

class Membership < ActiveRecord::Base
  enum type: %i(Membership CurrentMembership SuperMembership SelectedMembership TenantMembership)
  belongs_to :member, optional: true
  belongs_to :club, optional: true
end

class CurrentMembership < Membership
  belongs_to :member, optional: true
  belongs_to :club, inverse_of: :membership, optional: true
end

class SuperMembership < Membership
  belongs_to :member, -> { order("members.id DESC") }, optional: true
  belongs_to :club, optional: true
end

class SelectedMembership < Membership
  def self.default_scope
    select("'1' as foo")
  end
end

class TenantMembership < Membership
  cattr_accessor :current_member

  belongs_to :member, optional: true
  belongs_to :club, optional: true

  default_scope -> {
    if current_member
      where(member: current_member)
    else
      all
    end
  }
end
