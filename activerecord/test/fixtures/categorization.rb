class Categorization < ActiveRecord::Base
  belongs_to :post
  belongs_to :category
  belongs_to :author
end