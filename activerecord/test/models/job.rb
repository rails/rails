class Job < ActiveRecord::Base
  has_many :references
  has_many :people, :through => :references
  belongs_to :ideal_reference, :class_name => 'Reference'
end
