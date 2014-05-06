class Club < ActiveRecord::Base
  has_one :membership
  has_many :memberships, :inverse_of => false
  has_many :members, :through => :memberships
  has_one :sponsor
  has_many :author_sponsorables, -> { where(sponsorable_type: "Author") }, class_name: "Sponsor"
  has_many :sponsored_authors, through: :author_sponsorables, source: :sponsorable, source_type: "Author", class_name: "Author"
  has_many :hotel_sponsorables, -> { where(sponsorable_type: "Hotel") }, class_name: "Sponsor"
  has_many :sponsored_hotels, through: :hotel_sponsorables, source: :sponsorable, source_type: "Hotel", class_name: "Hotel"
  has_one :sponsored_member, :through => :sponsor, :source => :sponsorable, :source_type => "Member"
  belongs_to :category

  has_many :favourites, -> { where(memberships: { favourite: true }) }, through: :memberships, source: :member
  scope :with_sponsored_hotel, ->(hotel) {
    joins(:sponsored_hotels).where(hotels: {id: hotel.id})
  }
 
  scope :with_sponsored_author, ->(author) {
    joins(:sponsored_authors).where(authors: {id: author.id})
  }
 
  scope :with_sponsored_author_and_hotel, ->(author, hotel) {
    joins(:sponsored_authors).joins(:sponsored_hotels).where(authors: {id: author.id}, hotels: {id: hotel.id})
  }

  private

  def private_method
    "I'm sorry sir, this is a *private* club, not a *pirate* club"
  end
end
