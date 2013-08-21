class Project < ActiveRecord::Base
  has_and_belongs_to_many :developers, -> { uniq }
end
