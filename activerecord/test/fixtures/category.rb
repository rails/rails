class Category < ActiveRecord::Base
  has_and_belongs_to_many :posts
  
  def self.what_are_you
    'a category...'
  end
  
  has_many :categorizations
  has_many :authors, :through => :categorizations  
end

class SpecialCategory < Category
  
  def self.what_are_you
    'a special category...'
  end  
  
end
