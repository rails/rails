class Dog < ActiveRecord::Base
  belongs_to :breeder, class_name: "DogLover", counter_cache: :bred_dogs_count
  belongs_to :trainer, class_name: "DogLover", counter_cache: :trained_dogs_count
  belongs_to :doglover, foreign_key: :dog_lover_id, class_name: "DogLover", counter_cache: true
end
