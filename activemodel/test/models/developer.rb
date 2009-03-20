class Developer < ActiveRecord::Base
  validates_inclusion_of :salary, :in => 50000..200000
  validates_length_of :name, :within => 3..20

  attr_accessor :name_confirmation
end
