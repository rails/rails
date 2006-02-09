class Topic < ActiveRecord::Base
  has_many :replies, :include => [:user], :dependent => true
end