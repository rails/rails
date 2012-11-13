class Book < ActiveRecord::Base
  has_many :authors

  has_many :citations, :foreign_key => 'book1_id'
  has_many :references, -> { uniq }, :through => :citations, :source => :reference_of

  has_many :subscriptions
  has_many :subscribers, :through => :subscriptions
end
