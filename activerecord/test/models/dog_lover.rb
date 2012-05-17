class DogLover < ActiveRecord::Base
  has_many :trained_dogs, :class_name => "Dog", :foreign_key => :trainer_id
  has_many :bred_dogs, :class_name => "Dog", :foreign_key => :breeder_id
end
