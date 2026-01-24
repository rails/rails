# frozen_string_literal: true

class Membership < ActiveRecord::Base
  enum :type, %i(Membership CurrentMembership SuperMembership SelectedMembership TenantMembership)
  belongs_to :member
  belongs_to :club
  has_one :sponsor, through: :club

  belongs_to :simple_member, foreign_key: "member_id"
end

class CurrentMembership < Membership
  belongs_to :member
  belongs_to :club, inverse_of: :membership
end

class SuperMembership < Membership
  belongs_to :member, -> { order("members.id DESC") }
  belongs_to :club
end

class SelectedMembership < Membership
  def self.default_scope
    select("'1' as foo")
  end
end

class TenantMembership < Membership
  cattr_accessor :current_member

  belongs_to :member
  belongs_to :club

  default_scope -> {
    if current_member
      where(member: current_member)
    else
      all
    end
  }
end
