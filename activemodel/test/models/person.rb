class Person
  include ActiveModel::Validations
  extend  ActiveModel::Translation

  attr_accessor :title, :karma, :salary, :gender

  def condition_is_true
    true
  end
end

class Person::Gender
  extend ActiveModel::Translation
end

class Child < Person
end
