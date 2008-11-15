class MemberDetail < ActiveRecord::Base
  belongs_to :member
  belongs_to :organization
end
