class Person
  include ActiveModel::Validations
  extend  ActiveModel::Translation

  attr_accessor :title, :karma
end

class Child < Person
end
