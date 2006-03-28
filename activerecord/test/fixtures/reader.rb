class Reader < ActiveRecord::Base
  belongs_to :post
  belongs_to :person
end
