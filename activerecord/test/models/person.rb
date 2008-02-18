class Person < ActiveRecord::Base
  has_many :readers
  has_many :posts, :through => :readers
  has_many :posts_with_no_comments, :through => :readers, :source => :post, :include => :comments, :conditions => 'comments.id is null'
end
