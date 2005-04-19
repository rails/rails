class Post < ActiveRecord::Base
  belongs_to :author
  has_many   :comments, :order => "body"
  has_and_belongs_to_many :categories
end

class SpecialPost < Post
end