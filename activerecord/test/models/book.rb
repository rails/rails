class Book < ActiveRecord::Base
  has_many :authors

  has_many :citations, :foreign_key => 'book1_id'
  has_many :references, :through => :citations, :source => :reference_of, :uniq => true

  has_many :subscriptions
  has_many :subscribers, :through => :subscriptions

  has_many :reviews
end

class BookPositiveReview < Book
  default_scope { positive_reviews }

  def self.positive_reviews
    joins(:reviews).where(:reviews => {:positive => true})
  end
end
