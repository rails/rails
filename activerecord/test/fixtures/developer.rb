class Developer < ActiveRecord::Base
  has_and_belongs_to_many :projects

  validates_inclusion_of :salary, :in => 50000..200000
  validates_length_of    :name, :within => 3..20
end
