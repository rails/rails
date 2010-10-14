class Categorization < ActiveRecord::Base
  belongs_to :post
  belongs_to :category
  belongs_to :author
  
  has_many :post_taggings, :through => :author, :source => :taggings
end
