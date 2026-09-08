# frozen_string_literal: true

class Club < ActiveRecord::Base
  has_one :membership, touch: true
  has_many :memberships, inverse_of: false
  has_many :members, through: :memberships
  has_one :sponsor
  has_one :sponsored_member, through: :sponsor, source: :sponsorable, source_type: :Member
  belongs_to :category

  has_many :favorites, -> { where(memberships: { favorite: true }) }, through: :memberships, source: :member

  has_many :custom_memberships, class_name: "Membership"
  has_many :custom_favorites, -> { where(memberships: { favorite: true }) }, through: :custom_memberships, source: :member

  scope :general, -> { left_joins(:category).where(categories: { name: "General" }).unscope(:limit) }

  has_many :program_offerings
  has_many :programs, through: :program_offerings

  has_many :simple_memberships, class_name: "Membership"
  has_many :simple_members, through: :simple_memberships, foreign_key: "member_id"

  accepts_nested_attributes_for :membership

  private
    def private_method
      "I'm sorry sir, this is a *private* club, not a *pirate* club"
    end
end

class SuperClub < ActiveRecord::Base
  self.table_name = "clubs"

  has_many :memberships, class_name: "SuperMembership", foreign_key: "club_id"
  has_many :members, through: :memberships
end
