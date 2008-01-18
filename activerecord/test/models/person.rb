class Person < ActiveRecord::Base
  has_many :readers
  has_many :posts, :through => :readers
end
