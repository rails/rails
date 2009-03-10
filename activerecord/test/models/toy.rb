class Toy < ActiveRecord::Base
  set_primary_key :toy_id
  belongs_to :pet
end
