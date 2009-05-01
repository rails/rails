class Organization < ActiveRecord::Base
  has_many :member_details
  has_many :members, :through => :member_details
end

class SponsorableOrganization < Organization
  has_one  :sponsor, :as => :sponsorable
end