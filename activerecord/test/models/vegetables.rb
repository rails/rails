class Vegetable < ActiveRecord::Base

  validates_presence_of :name

  def self.inheritance_column
    'custom_type'
  end
end

class Cucumber < Vegetable
end

class Cabbage < Vegetable
end
