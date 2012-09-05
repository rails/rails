class Dog < ActiveRecord::Base
  INHERITANCE_TYPE_MAP = {
    2 => 'Labrador',
    3 => 'Retriever'
  }

  self.inheritance_column = 'dog_type'
  self.inheritance_serializer = ->(klass) { INHERITANCE_TYPE_MAP.invert[klass.name] }
  self.inheritance_deserializer = ->(type_before_cast) { INHERITANCE_TYPE_MAP[type_before_cast.to_i].constantize }

  belongs_to :breeder, :class_name => "DogLover", :counter_cache => :bred_dogs_count
  belongs_to :trainer, :class_name => "DogLover", :counter_cache => :trained_dogs_count
end

class Labrador < Dog
end

class Retriever < Dog
end
