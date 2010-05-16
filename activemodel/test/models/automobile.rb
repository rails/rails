class Automobile
  include ActiveModel::Validations

  validate :validations

  attr_accessor :make, :model

  def validations
    validates_presence_of :make
    validates_length_of   :model, :within => 2..10
  end
end