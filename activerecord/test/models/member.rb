class Member < ActiveRecord::Base
  has_one :current_membership
  has_many :memberships
  has_many :fellow_members, :through => :club, :source => :members
  has_one :club, :through => :current_membership
  has_one :favourite_club, :through => :memberships, :conditions => ["memberships.favourite = ?", true], :source => :club
  has_one :sponsor, :as => :sponsorable
  has_one :sponsor_club, :through => :sponsor
  has_one :member_detail
  has_one :organization, :through => :member_detail
end