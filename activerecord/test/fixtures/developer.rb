module DeveloperProjectsAssociationExtension
  def find_most_recent
    find(:first, :order => "id DESC")
  end
end

module DeveloperProjectsAssociationExtension2
  def find_least_recent
    find(:first, :order => "id ASC")
  end
end

class Developer < ActiveRecord::Base
  has_and_belongs_to_many :projects do
    def find_most_recent
      find(:first, :order => "id DESC")
    end
  end
  
  has_and_belongs_to_many :projects_extended_by_name, 
      :class_name => "Project", 
      :join_table => "developers_projects", 
      :association_foreign_key => "project_id",
      :extend => DeveloperProjectsAssociationExtension

  has_and_belongs_to_many :projects_extended_by_name_twice, 
      :class_name => "Project", 
      :join_table => "developers_projects", 
      :association_foreign_key => "project_id",
      :extend => [DeveloperProjectsAssociationExtension, DeveloperProjectsAssociationExtension2]

  has_and_belongs_to_many :projects_extended_by_name_and_block, 
      :class_name => "Project", 
      :join_table => "developers_projects", 
      :association_foreign_key => "project_id",
      :extend => DeveloperProjectsAssociationExtension do
        def find_least_recent
          find(:first, :order => "id ASC")
        end
      end

  has_and_belongs_to_many :special_projects, :join_table => 'developers_projects', :association_foreign_key => 'project_id'

  has_many :audit_logs

  validates_inclusion_of :salary, :in => 50000..200000
  validates_length_of    :name, :within => 3..20

  before_create do |developer|
    developer.audit_logs.build :message => "Computer created"
  end
end

class AuditLog < ActiveRecord::Base
  belongs_to :developer
end

DeveloperSalary = Struct.new(:amount)
class DeveloperWithAggregate < ActiveRecord::Base
  self.table_name = 'developers'
  composed_of :salary, :class_name => 'DeveloperSalary', :mapping => [%w(salary amount)]
end

class DeveloperWithBeforeDestroyRaise < ActiveRecord::Base
  self.table_name = 'developers'
  has_and_belongs_to_many :projects, :join_table => 'developers_projects', :foreign_key => 'developer_id'
  before_destroy :raise_if_projects_empty!

  def raise_if_projects_empty!
    raise if projects.empty?
  end
end
