class Book < ActiveRecord::Base
  has_many :citations, :foreign_key => 'book1_id'
  has_many :references, :through => :citations, :source => :reference_of, :uniq => true
end
