class Like < ActiveRecord::Base
  # Represents a legacy table with no primary key
  belongs_to :post
end
