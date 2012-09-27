class Comment < ActiveRecord::Base
  belongs_to :post
end
