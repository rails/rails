class Post < ActiveRecord::Base
  belongs_to :author
  has_many   :comments
end