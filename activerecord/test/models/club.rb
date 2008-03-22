class Club < ActiveRecord::Base
  has_many :memberships
  has_many :members, :through => :memberships
  has_many :current_memberships
  has_one :sponsor
  has_one :sponsored_member, :through => :sponsor, :source => :sponsorable, :source_type => "Member"
end