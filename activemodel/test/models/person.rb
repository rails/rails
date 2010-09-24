class Person
  include ActiveModel::Validations
  extend  ActiveModel::Translation

  attr_accessor :title, :karma, :salary, :gender

  def condition_is_true
    true
  end
end

class Child < Person
end

module PersonModule
  class Person < ::Person
  end
end
