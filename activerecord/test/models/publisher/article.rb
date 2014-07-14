class Publisher::Article < ActiveRecord::Base
  has_and_belongs_to_many :magazines
  has_and_belongs_to_many :tags
end
