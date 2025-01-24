# frozen_string_literal: true

class Member < ActiveRecord::Base
  has_one :current_membership
  has_one :selected_membership
  has_one :membership
  has_one :club, through: :current_membership
  has_one :club_without_joins, through: :current_membership, source: :club, disable_joins: true
  has_one :selected_club, through: :selected_membership, source: :club
  has_one :favorite_club, -> { where "memberships.favorite = ?", true }, through: :membership, source: :club
  has_one :hairy_club, -> { where clubs: { name: "Moustache and Eyebrow Fancier Club" } }, through: :membership, source: :club
  has_one :sponsor, as: :sponsorable
  has_one :sponsor_club, through: :sponsor
  has_one :member_detail, inverse_of: false
  has_one :organization, through: :member_detail
  has_one :organization_without_joins, through: :member_detail, disable_joins: true, source: :organization
  belongs_to :member_type

  has_many :nested_member_types, through: :member_detail, source: :member_type
  has_one :nested_member_type, through: :member_detail, source: :member_type

  has_many :nested_sponsors, through: :sponsor_club, source: :sponsor
  has_one :nested_sponsor, through: :sponsor_club, source: :sponsor

  has_many :organization_member_details, through: :member_detail
  has_many :organization_member_details_2, through: :organization, source: :member_details

  has_one :club_category, through: :club, source: :category
  has_one :general_club, -> { general }, through: :current_membership, source: :club

  has_many :super_memberships
  has_many :favorite_memberships, -> { where(favorite: true) }, class_name: "Membership"
  has_many :clubs, through: :favorite_memberships

  has_many :tenant_memberships
  has_many :tenant_clubs, through: :tenant_memberships, class_name: "Club", source: :club

  has_one :club_through_many, through: :favorite_memberships, source: :club

  belongs_to :admittable, polymorphic: true
  has_one :premium_club, through: :admittable

  scope :unnamed, -> { where(name: nil)  }
  scope :with_member_type_id, -> (id) { where(member_type_id: id) }
end

class SimpleMember < ActiveRecord::Base
  self.table_name = "members"

  has_many :memberships
  has_many :clubs, through: :memberships
end

class SelfMember < ActiveRecord::Base
  self.table_name = "members"
  has_and_belongs_to_many :friends, class_name: "SelfMember", join_table: "member_friends"
end
