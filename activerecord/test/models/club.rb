class Club < ActiveRecord::Base
  has_one :membership
  has_many :memberships, :inverse_of => false
  has_many :members, :through => :memberships
  has_one :sponsor
  has_one :sponsored_member, :through => :sponsor, :source => :sponsorable, :source_type => "Member"
  belongs_to :category

  private

  def private_method
    "I'm sorry sir, this is a *private* club, not a *pirate* club"
  end
end
