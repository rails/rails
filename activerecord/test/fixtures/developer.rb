class Developer < ActiveRecord::Base
  has_and_belongs_to_many :projects
  has_and_belongs_to_many :special_projects, :join_table => 'developers_projects', :association_foreign_key => 'project_id'
	
  validates_inclusion_of :salary, :in => 50000..200000
  validates_length_of    :name, :within => 3..20
end

DeveloperSalary = Struct.new(:amount)
class DeveloperWithAggregate < ActiveRecord::Base
  self.table_name = 'developers'
  composed_of :salary, :class_name => 'DeveloperSalary', :mapping => [%w(salary amount)]
end
