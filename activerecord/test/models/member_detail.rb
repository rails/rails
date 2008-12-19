class MemberDetail < ActiveRecord::Base
  belongs_to :member
  belongs_to :organization
  has_one :member_type, :through => :member
end
