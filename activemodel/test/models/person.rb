class Person
  include ActiveModel::Validations
  extend  ActiveModel::Translation

  attr_accessor :title, :karma, :salary, :gender, :nicknames

  def initialize(attributes = {})
    attributes.each do |key, value|
      send "#{key}=", value
    end
  end

  def condition_is_true
    true
  end
end

class Person::Gender
  extend ActiveModel::Translation
end

class Child < Person
end
