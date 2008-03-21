class Club < ActiveRecord::Base
  has_many :memberships
  has_many :members, :through => :memberships
  has_many :current_memberships
  has_many :sponsors
end