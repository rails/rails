class Automobile
  extend ActiveModel::Naming
  include ActiveModel::Validations

  validate :validations

  attr_accessor :make, :model

  def model_name
      name = self.class.model_name
      name.instance_variable_set :@plural, "#{make}_#{model}s".downcase
      name
  end

  def validations
    validates_presence_of :make
    validates_length_of   :model, :within => 2..10
  end
end