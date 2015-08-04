class Organization < ActiveRecord::Base
  has_many :member_details
  has_many :members, :through => :member_details

  has_many :authors, :primary_key => :name
  has_many :author_essay_categories, :through => :authors, :source => :essay_categories

  has_one :author, :primary_key => :name
  has_one :author_owned_essay_category, :through => :author, :source => :owned_essay_category

  has_many :posts, :through => :author, :source => :posts

  scope :clubs, -> { from('clubs') }
end
