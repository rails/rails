class Drink < ActiveRecord::Base
  belongs_to :bar, :class_name => 'Club'
end
